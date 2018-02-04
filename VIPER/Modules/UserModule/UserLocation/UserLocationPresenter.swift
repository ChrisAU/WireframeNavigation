import Foundation
import Action
import RxSwift

protocol UserLocationView: TitlableView, ClosableView, AlertableView, Viewable {
    func setUserLocation(_ userLocation: UserLocation)
}

class UserLocationPresenter<T: UserLocationView>: Presenter<T> {
    private let interactor: UserLocationInteractor
    private let userId: Int
    
    init(interactor: UserLocationInteractor, userId: Int) {
        self.interactor = interactor
        self.userId = userId
    }
    
    override func attachView(_ view: T) {
        super.attachView(view)
        
        let user = interactor.user(with: userId)
        
        if let user = user {
            view.setTitle("\(user.firstName)'s Location")
        } else {
            view.setTitle("Unknown User's Location")
        }
        
        if let location = interactor.location(with: userId) {
            view.setUserLocation(location)
        } else {
            let okAction = Action<String, Void>() { title in
                return view.dismissAlert()
                    .asObservable()
                    .map { _ in () }
            }
            let okOption = Alert.Option(title: "OK", style: .cancel, action: okAction)
            
            let name = user?.firstName ?? "unknown"
            let alert = Alert(title: "No Location", message: "Location for \(name) is unavailable.", style: .alert, options: [okOption])
            
            disposeOnViewDetach(view.presentAlert(alert).subscribe())
        }
        
        let action = CocoaAction { [weak self] _ in
            guard let wireframe = self?.wireframe else { return .empty() }
            return .deferred {
                return wireframe.navigate(to: view.parent(), animated: true)
                    .asObservable()
                    .map { _ in () }
            }
        }
        
        view.setCloseAction(action)
        view.setCloseTitle("Close")
    }
}
