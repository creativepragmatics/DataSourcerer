import Foundation

public struct PlainCacheDatasource<Value_, P_: Parameters, E_: DatasourceError> : DatasourceProtocol {

    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<P>
    public typealias StatePersisterConcrete = AnyStatePersister<Value, P, E>

    public let loadsSynchronously = true
    private let persister: StatePersisterConcrete
    public var loadImpulseEmitter: LoadImpulseEmitterConcrete
    private let cacheLoadError: E
    private let observableCore = DatasourceObservableCore<Value, P, E>()
    private let disposeBag = DisposeBag()

    public init(persister: StatePersisterConcrete,
                loadImpulseEmitter: LoadImpulseEmitterConcrete,
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

        loadImpulseEmitter.observe { [weak observableCore] loadImpulse in
            let state: DatasourceState = {
                guard let cached = persister.load(loadImpulse.parameters) else {
                    return DatasourceState.error(error: cacheLoadError,
                                                 loadImpulse: loadImpulse,
                                                 fallbackValue: nil)
                }

                return cached
            }()
            observableCore?.emit(state)
        }.disposed(by: disposeBag)

        return observableCore.observe(statesOverTime)
    }

}
