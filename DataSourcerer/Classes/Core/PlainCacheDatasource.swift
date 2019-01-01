import Foundation

public final class PlainCacheDatasource<Value_, P_: Parameters, E_: DatasourceError> :
StateDatasourceProtocol {

    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias StatePersisterConcrete = AnyStatePersister<Value, P, E>

    public let persister: StatePersisterConcrete
    private var loadImpulseEmitter: AnyLoadImpulseEmitter<P>
    public let cacheLoadError: E
    public var currentValue: SynchronizedProperty<DatasourceState> {
        return coreDatasource.currentValue
    }

    private let coreDatasource = SimpleDatasource<State<Value, P, E>>(.notReady)
    private let disposeBag = DisposeBag()

    public init(persister: StatePersisterConcrete,
                loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
                cacheLoadError: E) {

        self.persister = persister
        self.loadImpulseEmitter = loadImpulseEmitter
        self.cacheLoadError = cacheLoadError
    }

    public func observe(_ statesOverTime: @escaping StatesOverTime) -> Disposable {

        let persister = self.persister // avoid refer self in closure
        let cacheLoadError = self.cacheLoadError // avoid capturing self in closure

        defer {
            loadImpulseEmitter.observe { [weak coreDatasource] loadImpulse in
                let state: DatasourceState = {
                    guard let cached = persister.load(loadImpulse.parameters) else {
                        return DatasourceState.error(error: cacheLoadError,
                                                     loadImpulse: loadImpulse,
                                                     fallbackValueBox: nil)
                    }

                    return cached
                }()
                coreDatasource?.emit(state)
            }.disposed(by: disposeBag)
        }

        let disposable = coreDatasource.observe(statesOverTime)
        return CompositeDisposable(disposable, objectToRetain: self)
    }

    public func removeObserver(with key: Int) {
        coreDatasource.removeObserver(with: key)
    }

}
