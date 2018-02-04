import Foundation
import RxSwift

protocol UsersView: TitlableView, Viewable {
    var selectedUser: PublishSubject<User> { get }
    
    func showUsers(_ users: [User])
}

class UsersPresenter<T: UsersView>: Presenter<T> {
    private let interactor: UsersInteractor
    
    init(interactor: UsersInteractor) {
        self.interactor = interactor
    }
    
    override func attachView(_ newView: T) {
        super.attachView(newView)
        
        newView.setTitle("Users")
        newView.showUsers(interactor.get())
        
        disposeOnViewDetach(newView.selectedUser.asObservable().flatMap { [weak self] (user) -> Observable<Never> in
            guard let wireframe = self?.wireframe else {
                return .empty()
            }
            return wireframe.navigate(to: "\(newView.routePath)/\(user.id)", animated: true)
                .asObservable()
        }.subscribe())
    }
}
