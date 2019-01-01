import Foundation

open class LoadingEndedObservable
    <Value, P: Parameters, E: DatasourceError> : TypedObservable {
    public typealias ObservedValue = Void
    public typealias EndedLoadingEventsOverTime = (()) -> Void
    public typealias SourceObservable = AnyStatefulObservable<State<Value, P, E>>

    private let sourceObservable: AnyStatefulObservable<State<Value, P, E>>
    private let loadImpulseEmitter: AnyLoadImpulseEmitter<P>
    private let disposeBag = DisposeBag()
    private var isLoading = SynchronizedMutableProperty<Bool>(false)
    private var isObserved = SynchronizedMutableProperty<Bool>(false)
    private let innerObservable = DefaultStatefulObservable<Void>(())
    private let executer: SynchronizedExecuter

    init(sourceObservable: SourceObservable,
         loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
         queue: DispatchQueue = .main) {
        self.sourceObservable = sourceObservable
        self.loadImpulseEmitter = loadImpulseEmitter
        self.executer = SynchronizedExecuter(queue: queue)
    }

    public func observe(_ valuesOverTime: @escaping EndedLoadingEventsOverTime) -> Disposable {

        let innerDisposable = innerObservable.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable.add(startObserving())
        }

        return compositeDisposable
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

    private func startObserving() -> Disposable {

        let disposable = CompositeDisposable()

        disposable += loadImpulseEmitter
            .observe { [weak self] _ in
                self?.isLoading.value = true
            }

        disposable += sourceObservable
            .observe { [weak self] state in
                guard let self = self,
                    self.isLoading.value,
                    state.loadImpulse?.parameters != nil else { return }

                switch state.provisioningState {
                case .result:
                    self.isLoading.value = false
                    self.executer.async { [weak self] in
                        self?.innerObservable.emit(())
                    }
                case .notReady, .loading:
                    break
                }
            }

        return disposable
    }

}

public extension StatefulObservable {

    func loadingEndedEvents<Value, P: Parameters, E: DatasourceError>(
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
        queue: DispatchQueue = .main)
        -> LoadingEndedObservable<Value, P, E> where ObservedValue == State<Value, P, E> {

            return LoadingEndedObservable<Value, P, E>(
                sourceObservable: self.any,
                loadImpulseEmitter: loadImpulseEmitter,
                queue: queue
            )
    }
}
