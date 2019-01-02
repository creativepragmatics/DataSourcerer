import Foundation

open class LoadingEndedObservable
    <Value, P: Parameters, E: DatasourceError> : ObservableProtocol {
    public typealias ObservedValue = Void
    public typealias EndedLoadingEventsOverTime = (()) -> Void
    public typealias SourceDatasource = AnyDatasource<State<Value, P, E>>

    private let sourceDatasource: AnyDatasource<State<Value, P, E>>
    private let loadImpulseEmitter: AnyLoadImpulseEmitter<P>
    private let disposeBag = DisposeBag()
    private var isLoading = SynchronizedMutableProperty<Bool>(false)
    private var isObserved = SynchronizedMutableProperty<Bool>(false)
    private let coreDatasource = SimpleDatasource<Void>(())
    private let executer: SynchronizedExecuter

    init(sourceDatasource: SourceDatasource,
         loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
         queue: DispatchQueue = .main) {
        self.sourceDatasource = sourceDatasource
        self.loadImpulseEmitter = loadImpulseEmitter
        self.executer = SynchronizedExecuter(queue: queue)
    }

    public func observe(_ valuesOverTime: @escaping EndedLoadingEventsOverTime) -> Disposable {

        let innerDisposable = coreDatasource.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable.add(startObserving())
        }

        return compositeDisposable
    }

    private func startObserving() -> Disposable {

        let disposable = CompositeDisposable()

        disposable += loadImpulseEmitter
            .observe { [weak self] _ in
                self?.isLoading.value = true
            }

        disposable += sourceDatasource
            .observe { [weak self] state in
                guard let self = self,
                    self.isLoading.value,
                    state.loadImpulse?.parameters != nil else { return }

                switch state.provisioningState {
                case .result:
                    self.isLoading.value = false
                    self.executer.async { [weak self] in
                        self?.coreDatasource.emit(())
                    }
                case .notReady, .loading:
                    break
                }
            }

        return disposable
    }

}

public extension DatasourceProtocol {

    func loadingEndedEvents<Value, P: Parameters, E: DatasourceError>(
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
        queue: DispatchQueue = .main)
        -> LoadingEndedObservable<Value, P, E> where ObservedValue == State<Value, P, E> {

            return LoadingEndedObservable<Value, P, E>(
                sourceDatasource: self.any,
                loadImpulseEmitter: loadImpulseEmitter,
                queue: queue
            )
    }
}
