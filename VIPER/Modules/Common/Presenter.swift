import Foundation
import RxSwift

class Presenter<T> {
    typealias View = T
    private var disposeBag = DisposeBag()
    private var view: View?
    private var subPresenters: [Presenter<T>] = []
    var wireframe: Wireframe?
    
    func attachPresenter(_ presenter: Presenter<T>) {
        subPresenters.append(presenter)
    }
    
    func attachWireframe(_ newWireframe: Wireframe) {
        wireframe = newWireframe
    }
    
    func attachView(_ view: View) {
        assert(self.view == nil)
        self.view = view
        subPresenters.forEach { $0.attachView(view) }
    }
    
    func detachView() {
        subPresenters.forEach { $0.detachView() }
        view = nil
        disposeBag = DisposeBag()
    }
    
    func disposeOnViewDetach(_ disposable: Disposable) {
        subPresenters.forEach { $0.disposeOnViewDetach(disposable) }
        disposeBag.insert(disposable)
    }
}
