import Foundation

public struct PlainCacheDatasource<Value_, P_: Parameters, E_: DatasourceError> : DatasourceProtocol {

    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias StatePersisterConcrete = AnyStatePersister<Value, P, E>

    public let loadsSynchronously = true
    public let persister: StatePersisterConcrete
    public var loadImpulseEmitter: AnyLoadImpulseEmitter<P>
    public let cacheLoadError: E
    public var lastValue: SynchronizedProperty<DatasourceState?> {
        return innerObservable.lastValue
    }

    private let innerObservable = InnerStateObservable<Value, P, E>()
    private let disposeBag = DisposeBag()

    public init(persister: StatePersisterConcrete,
                loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
                cacheLoadError: E) {

        self.persister = persister
        self.loadImpulseEmitter = loadImpulseEmitter
        self.cacheLoadError = cacheLoadError
    }

    public func observe(_ statesOverTime: @escaping StatesOverTime) -> Disposable {
        // Send .notReady right now, because loadsSynchronously == true
        statesOverTime(DatasourceState.notReady)

        let persister = self.persister // avoid refer self in closure
        let cacheLoadError = self.cacheLoadError // avoid capturing self in closure

        defer {
            loadImpulseEmitter.observe { [weak innerObservable] loadImpulse in
                let state: DatasourceState = {
                    guard let cached = persister.load(loadImpulse.parameters) else {
                        return DatasourceState.error(error: cacheLoadError,
                                                     loadImpulse: loadImpulse,
                                                     fallbackValueBox: nil)
                    }

                    return cached
                }()
                innerObservable?.emit(state)
            }.disposed(by: disposeBag)
        }

        return innerObservable.observe(statesOverTime)
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

}
