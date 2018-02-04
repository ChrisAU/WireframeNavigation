import Foundation
import RxSwift
import RxTest
import RxBlocking
import XCTest
@testable import VIPER

class NavigatorMock: Navigator {
    let viewablesMock = Mock([Viewable]())
    var viewables: [Viewable] {
        return viewablesMock.execute()
    }
    
    let dismissMock = Mock(Completable.empty())
    func dismiss(with mode: NavigationMode, animated: Bool) -> Completable {
        viewablesMock.set(Array(viewablesMock.value.dropLast()))
        return dismissMock.execute()
    }
    
    let presentMock = Mock(Completable.empty())
    func present(view: Viewable, with mode: NavigationMode, animated: Bool) -> Completable {
        viewablesMock.set(viewablesMock.value + [view])
        return presentMock.execute()
    }
}

class ViewableMock: Viewable {
    var routeIdentifier: String = ""
    var routePath: String = ""
    var navigationMode: NavigationMode = RootNavigation()
}

class WireframeTests: XCTestCase {
    var disposeBag: DisposeBag!
    var testScheduler: TestScheduler!
    var wireframe: AppWireframe!
    var navigator: NavigatorMock!
    var view: ViewableMock!

    func testGivenAddedRoute_whenNavigateIsCalled_thenExpectNavigation() {
        wireframe.add("/", mode: RootNavigation(), navigator: navigator, viewFactory: { _ in self.view })
        let observer = testScheduler.createObserver(Observable<Never>.E.self)
        testScheduler.scheduleAt(1) {
            self.wireframe.navigate(to: "/")
                    .asObservable().subscribe(observer)
                    .disposed(by: self.disposeBag)
        }
        testScheduler.start()
        XCTAssertTrue(observer.events.last!.value.isCompleted)
        navigator.presentMock.expect(count: .toBeOne)
        navigator.dismissMock.expect(count: .toBeZero)
        XCTAssert(view.navigationMode is RootNavigation)
        XCTAssertEqual(view.routeIdentifier, "/")
        XCTAssertEqual(view.routePath, "/")
    }

    func testGivenAddedRoutes_whenNavigateIsCalled_thenExpectNavigationMultipleTimes() {
        let secondView = ViewableMock()
        wireframe.add("/", mode: RootNavigation(), navigator: navigator, viewFactory: { _ in self.view })
        wireframe.add("/:place", mode: PushNavigation(), navigator: navigator, viewFactory: { _ in secondView })
        let observer = testScheduler.createObserver(Observable<Never>.E.self)
        testScheduler.scheduleAt(1) {
            self.wireframe.navigate(to: "/root")
                .asObservable()
                .subscribe(observer)
                .disposed(by: self.disposeBag)
        }
        testScheduler.start()
        XCTAssertTrue(observer.events.last!.value.isCompleted)
        navigator.presentMock.expect(count: .toBe(2))
        navigator.dismissMock.expect(count: .toBeZero)
        XCTAssert(view.navigationMode is RootNavigation)
        XCTAssert(secondView.navigationMode is PushNavigation)
        XCTAssertEqual(view.routeIdentifier, "/")
        XCTAssertEqual(view.routePath, "/")
        XCTAssertEqual(secondView.routeIdentifier, "/:place")
        XCTAssertEqual(secondView.routePath, "/root")
    }

    func testGivenAddedRoute_whenNavigateIsCalledMultipleTimes_thenExpectNavigationForwardsAndBackwards() {
        var firstParameters: [String: String] = [:]
        let secondView = ViewableMock()
        var secondParameters: [String: String] = [:]
        let thirdView = ViewableMock()
        var thirdParameters: [String: String] = [:]
        wireframe.add("/", mode: RootNavigation(), navigator: navigator, viewFactory: {
            firstParameters = $0
            return self.view
        })
        wireframe.add("/:userid", mode: PushNavigation(), navigator: navigator, viewFactory: {
            secondParameters = $0
            return secondView
        })
        wireframe.add("/:userid/:country", mode: ModalNavigation(), navigator: navigator, viewFactory: {
            thirdParameters = $0
            return thirdView
        })
        let observer = testScheduler.createObserver(Observable<Never>.E.self)
        testScheduler.scheduleAt(1) {
            self.wireframe.navigate(to: "/")
                .andThen(Completable.deferred { self.wireframe.navigate(to: "/123")})
                .andThen(Completable.deferred { self.wireframe.navigate(to: "/123/uk")})
                .andThen(Completable.deferred { self.wireframe.navigate(to: "/")})
                .asObservable()
                .subscribe(observer)
                .disposed(by: self.disposeBag)
        }
        testScheduler.start()
        XCTAssertTrue(observer.events.last!.value.isCompleted)
        navigator.presentMock.expect(count: .toBe(3))
        navigator.dismissMock.expect(count: .toBe(2))
        
        XCTAssert(view.navigationMode is RootNavigation)
        XCTAssertEqual(view.routeIdentifier, "/")
        XCTAssertEqual(view.routePath, "/")
        XCTAssertEqual(firstParameters, [:])
        
        XCTAssert(secondView.navigationMode is PushNavigation)
        XCTAssertEqual(secondView.routeIdentifier, "/:userid")
        XCTAssertEqual(secondView.routePath, "/123")
        XCTAssertEqual(secondParameters, ["userid": "123"])
        
        XCTAssert(thirdView.navigationMode is ModalNavigation)
        XCTAssertEqual(thirdView.routeIdentifier, "/:userid/:country")
        XCTAssertEqual(thirdView.routePath, "/123/uk")
        XCTAssertEqual(thirdParameters, ["userid": "123", "country": "uk"])
    }


    override func setUp() {
        super.setUp()
        disposeBag = DisposeBag()
        view = ViewableMock()
        navigator = NavigatorMock()
        testScheduler = TestScheduler(initialClock: 0)
        wireframe = AppWireframe()
    }
    
    override func tearDown() {
        super.tearDown()
        disposeBag = nil
        view = nil
        navigator = nil
        testScheduler = nil
        wireframe = nil
    }
}
