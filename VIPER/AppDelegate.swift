//
//  AppDelegate.swift
//  VIPER
//
//  Created by Chris Nevin on 28/01/2018.
//  Copyright © 2018 Chris Nevin. All rights reserved.
//

import UIKit
import RxSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    private let wireframe = AppWireframe()
    
    var window: UIWindow?
    
    private let disposeBag = DisposeBag()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        let userNavigationController = UINavigationController()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = userNavigationController
        window?.makeKeyAndVisible()
        
        self.addUserFlow(with: userNavigationController, to: self.wireframe)
        
        wireframe.navigate(to: "/users/1/location", animated: true)
            .subscribe()
            .disposed(by: disposeBag)
        
        return true
    }
    
    func addUserFlow(with navigator: Navigator, to wireframe: Wireframe) {
        let userDataStore = UserMemoryStore()
        
        wireframe.add("/users", mode: PushNavigation(), navigator: navigator, viewFactory: { (parameters) -> (Viewable) in
            
            let interactor = UsersInteractor(dataStore: userDataStore)
            let presenter = UsersPresenter<UsersViewController>(interactor: interactor)
            presenter.attachWireframe(wireframe)
            
            let controller = UsersViewController(style: UITableViewStyle.plain)
            controller.presenter = presenter
            
            return controller
        })
        
        wireframe.add("/users/:userID", mode: PushNavigation(), navigator: navigator, viewFactory: { (parameters) -> (Viewable) in
            
            let userId = Int(parameters["userID"]!)!
            let interactor = UserInteractor(dataStore: userDataStore)
            let presenter = UserPresenter<UserViewController>(interactor: interactor, userId: userId)
            presenter.attachWireframe(wireframe)
            
            let controller = UserViewController(nibName: nil, bundle: nil)
            controller.presenter = presenter
            
            return controller
        })
        
        let userLocationDataStore = UserLocationMemoryDataStore()
        
        wireframe.add("/users/:userID/location", mode: ModalNavigation(), navigator: navigator, viewFactory: { (parameters) -> (Viewable) in
            
            let userId = Int(parameters["userID"]!)!
            let interactor = UserLocationInteractor(
                userDataStore: userDataStore,
                userLocationDataStore: userLocationDataStore)
            let presenter = UserLocationPresenter<UserLocationViewController>(
                interactor: interactor,
                userId: userId)
            presenter.attachWireframe(wireframe)
            
            let controller = UserLocationViewController(nibName: nil, bundle: nil)
            controller.presenter = presenter
            
            return UINavigationController(rootViewController: controller)
        })
    }
}

