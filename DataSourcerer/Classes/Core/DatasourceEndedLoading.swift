import Foundation

open class DatasourceEndedLoading<Datasource: DatasourceProtocol>: Observable {
    public typealias EndedLoadingEventsOverTime = () -> ()
    
    private let datasource: Datasource
    private let loadImpulseEmitter: AnyLoadImpulseEmitter<Datasource.P>
    private let disposeBag = DisposeBag()
    private var isLoading = SynchronizedProperty<Bool>(false)
    private var isObserved = SynchronizedProperty<Bool>(false)
    private let innerObservable = DefaultObservable<Void>()
    
    init(datasource: Datasource, loadImpulseEmitter: AnyLoadImpulseEmitter<Datasource.P>) {
        self.datasource = datasource
        self.loadImpulseEmitter = loadImpulseEmitter
    }
    
    private func startObserving() {
        
        loadImpulseEmitter
            .observe { [weak self] _ in
                self?.isLoading.value = true
            }
            .disposed(by: disposeBag)
        
        datasource
            .observe { [weak self] state in
                guard let self = self, self.isLoading.value == false else { return }
    
                switch state.provisioningState {
                case .result:
                    self.isLoading.value = false
                    self.innerObservable.emit(())
                case .notReady, .loading:
                    break
                }
            }
            .disposed(by: disposeBag)
    }
    
    public func observe(_ observe: @escaping EndedLoadingEventsOverTime) -> Disposable {
        
        defer {
            let isFirstObservation = isObserved.set(true, ifCurrentValueIs: false)
            if isFirstObservation {
                startObserving()
            }
        }
        
        let innerDisposable = innerObservable.observe(observe)
        let selfDisposable: Disposable = InstanceRetainingDisposable(self)
        return CompositeDisposable([innerDisposable, selfDisposable])
    }
    
    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }
    
}

public extension DatasourceProtocol {
    
    public func observeEndedLoading(loadImpulseEmitter: AnyLoadImpulseEmitter<P>, _ endedLoadingEventsOverTime: @escaping DatasourceEndedLoading<Self>.EndedLoadingEventsOverTime) -> Disposable {
        return DatasourceEndedLoading.init(datasource: self, loadImpulseEmitter: loadImpulseEmitter).observe(endedLoadingEventsOverTime)
    }
}
