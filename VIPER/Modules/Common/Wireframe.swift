import Foundation
import RxSwift

enum RouteError: Error {
    case alreadyAtRoot
    case invalidPath(String)
    case unhandledNavigation(NavigationMode)
}

protocol Wireframe {
    func add(_ definition: String,
             mode: NavigationMode,
             navigator: Navigator,
             viewFactory: @escaping ([String: String]) -> (Viewable))
    func navigate(to path: String, animated: Bool) -> Completable
}

class AppWireframe: Wireframe {
    private var routes: [RouteInfo] = []
    
    func add(_ definition: String,
             mode: NavigationMode,
             navigator: Navigator,
             viewFactory: @escaping ([String: String]) -> (Viewable)) {
        routes.append(RouteInfo(definition: definition,
                                mode: mode,
                                navigator: navigator,
                                viewFactory: viewFactory))
        routes.sort(by: { $0.definition < $1.definition })
    }
    
    /// Use when navigating entire tree to find a particular node executing each child along the way.
    func navigate(to path: String, animated: Bool = false) -> Completable {
        return Completable.deferred {
            self.routes.route(to: path, animated: animated)
        }
    }
}

private let definitionPrefix: Character = ":"
private let routeDelimiter: Character = "/"

extension Viewable {
    func parent() -> String {
        return String(routeDelimiter) +
            routePath.split(separator: routeDelimiter)
                .dropLast()
                .joined(separator: String(routeDelimiter))
    }
    
    func child(named name: String) -> String {
        return "\(routePath)\(routeDelimiter)\(name)"
    }
}

private struct Route {
    let identifier: String
    let path: String
    let parameters: [String: String]
}

private struct RoutePatternProvider {
    private let anyParameterPattern: NSRegularExpression
    let isolatedParameterPattern: NSRegularExpression
    
    init() {
        self.anyParameterPattern = try! NSRegularExpression(
            pattern: "(\(definitionPrefix)[^\(routeDelimiter)]+)",
            options: .caseInsensitive)
        self.isolatedParameterPattern = try! NSRegularExpression(
            pattern: "^\(definitionPrefix)((.)+)$",
            options: .caseInsensitive)
    }
    
    func parameterIgnoringPattern(`for` definition: String) -> NSRegularExpression {
        let pattern = anyParameterPattern.stringByReplacingMatches(
            in: definition,
            options: .withoutAnchoringBounds,
            range: definition.getNSRange(),
            withTemplate: "[^\(routeDelimiter)]+")
        
        return try! NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive)
    }
}

private extension NSRegularExpression {
    func match(`for` text: String) -> NSTextCheckingResult? {
        return matches(
            in: text,
            options: .withoutAnchoringBounds,
            range: text.getNSRange()).first
    }
}

private extension NSRange {
    func next() -> NSRange {
        return NSRange(location: location + 1, length: length - 1)
    }
}

private extension String {
    func getNSRange() -> NSRange {
        return NSRange(location: 0, length: count)
    }
}

private struct RouteDefinitionToRouteConverter {
    private let patternProvider: RoutePatternProvider
    private let definition: String
    private let isResponsiblePattern: NSRegularExpression
    
    init(definition: String) {
        self.definition = definition
        self.patternProvider = RoutePatternProvider()
        self.isResponsiblePattern = patternProvider.parameterIgnoringPattern(for: definition)
    }
    
    func matches(_ path: String, _ otherPath: String) -> Bool {
        if path.count <= otherPath.count {
            return path == otherPath[..<path.endIndex]
        } else {
            return false
        }
    }
    
    func trim(path: String) -> String {
        return String(routeDelimiter) +
            zip(path.split(separator: routeDelimiter),
                definition.split(separator: routeDelimiter))
                .map { $0.0 }
                .joined(separator: String(routeDelimiter))
    }
    
    func route(`for` path: String, exact: Bool = true) -> Route? {
        guard !exact ||
            (exact && path.split(separator: routeDelimiter).count == definition.split(separator: routeDelimiter).count) else {
                return nil
        }
        guard isResponsible(for: path) else {
            return nil
        }
        return Route(identifier: definition,
                     path: trim(path: path),
                     parameters: extractParameters(from: path))
    }
    
    private func isResponsible(`for` route: String) -> Bool {
        return isResponsiblePattern.match(for: route) != nil
    }
    
    private func extractParameters(from route: String) -> [String: String] {
        return zip(definition.split(separator: routeDelimiter),
                   route.split(separator: routeDelimiter))
            .reduce([:]) { (params, parts) in
                let definitionPart = String(parts.0)
                guard let match = patternProvider.isolatedParameterPattern.match(for: definitionPart) else {
                    return params
                }
                let parameter = (definitionPart as NSString).substring(with: match.range.next())
                var newParams = params
                newParams[parameter] = String(parts.1)
                return newParams
        }
    }
}

private class RouteInfo {
    let definition: String
    let converter: RouteDefinitionToRouteConverter
    let mode: NavigationMode
    let navigator: Navigator
    let viewFactory: ([String: String]) -> (Viewable)
    
    init(definition: String,
         mode: NavigationMode,
         navigator: Navigator,
         viewFactory: @escaping ([String: String]) -> (Viewable)) {
        self.definition = definition
        self.converter = RouteDefinitionToRouteConverter(definition: definition)
        self.navigator = navigator
        self.mode = mode
        self.viewFactory = viewFactory
    }
}

private extension Array where Iterator.Element == RouteInfo {
    private func makeCompletable(from completables: [Completable], forPath path: String) -> Completable {
        guard !completables.isEmpty else {
            return Completable.error(RouteError.invalidPath(path))
        }
        return Completable.concat(completables)
    }
    
    func route(to path: String, animated: Bool) -> Completable {
        var hasRoot: Bool = false
        var dismissed: [Completable] = [.empty()]
        
        if let top = Array(self).first {
            if top.navigator.viewables.count > 0 {
                hasRoot = true
            }
            dismissed += top.navigator.viewables.dropFirst().reversed().map { view in
                guard top.converter.matches(view.routePath, path) else {
                    return Completable.deferred {
                        return top.navigator.dismiss(with: view.navigationMode, animated: true)
                    }
                }
                return .empty()
            }
        }
        
        let remaining = hasRoot ? Array(dropFirst(dismissed.count)) : self
        
        let presented = remaining.flatMap ({ info -> Completable? in
            guard let route = info.converter.route(for: path, exact: false) else {
                return nil
            }
            return Completable.deferred {
                var view = info.viewFactory(route.parameters)
                view.routeIdentifier = route.identifier
                view.routePath = route.path
                view.navigationMode = info.mode
                return info.navigator.present(view: view,
                                              with: info.mode,
                                              animated: animated)
            }
        })
        
        return Completable.concat(dismissed)
            .andThen(Completable.concat(presented))
    }
}

