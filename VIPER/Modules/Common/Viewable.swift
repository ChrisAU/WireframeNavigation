import UIKit
import ObjectiveC

protocol Viewable {
    var routeIdentifier: String { get set }
    var routePath: String { get set }
    var navigationMode: NavigationMode { get set }
    func parent() -> String
    func child(named name: String) -> String
}

private var routeIdentifierKey: UInt8 = 0
private var routePathKey: UInt8 = 1
private var navigationModeKey: UInt8 = 2

extension UIViewController: Viewable {
    /// Return target view controller that will be attached to the Presenter.
    /// If any nesting has happened we should strip it out here.
    private var targetViewController: UIViewController {
        if let navigationController = self as? UINavigationController,
            let rootViewController = navigationController.viewControllers.first {
            return rootViewController
        }
        return self
    }
    
    private func associatedObject<T>(key: UnsafeRawPointer) -> T {
        return objc_getAssociatedObject(targetViewController, key) as! T
    }
    private func associateObject<T>(_ object: T, forKey key: UnsafeRawPointer) {
        objc_setAssociatedObject(targetViewController, key, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    var routeIdentifier: String {
        get {
            return associatedObject(key: &routeIdentifierKey)
        }
        set {
            associateObject(newValue, forKey: &routeIdentifierKey)
        }
    }
    
    var routePath: String {
        get {
            return associatedObject(key: &routePathKey)
        }
        set {
            associateObject(newValue, forKey: &routePathKey)
        }
    }
    
    var navigationMode: NavigationMode {
        get {
            return associatedObject(key: &navigationModeKey)
        }
        set {
            associateObject(newValue, forKey: &navigationModeKey)
        }
    }
}

