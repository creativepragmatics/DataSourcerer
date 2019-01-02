import Foundation

/// Maintains state coming from multiple sources (primary and cache).
/// It is able to support pagination, live feeds, etc in the primary
/// datasource (yet to be implemented).
/// State coming from the primary datasource is treated as preferential
/// over state from the cache datasource.
open class CachedDatasource<Value_, P_: Parameters, E_: DatasourceError>: StateDatasourceProtocol {

    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias SubDatasource = AnyDatasource<State<Value, P, E>>
    public typealias StatePersisterConcrete = AnyStatePersister<Value, P, E>

    public var currentValue: SynchronizedProperty<DatasourceState> {
        return coreDatasource.currentValue
    }
    public let loadImpulseEmitter: AnyLoadImpulseEmitter<P>

    private let primaryDatasource: SubDatasource
    private let cacheDatasource: SubDatasource
    private let persister: StatePersisterConcrete?
    private let coreDatasource = SimpleDatasource<State<Value, P, E>>(.notReady)
    private let disposeBag = DisposeBag()
    private var currentStateComponents = SynchronizedMutableProperty(StateComponents.initial)

    public init(loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
                primaryDatasource: SubDatasource,
                cacheDatasource: SubDatasource,
                persister: StatePersisterConcrete?) {
        self.loadImpulseEmitter = loadImpulseEmitter
        self.primaryDatasource = primaryDatasource
        self.cacheDatasource = cacheDatasource
        self.persister = persister
    }

    public func observe(_ statesOverTime: @escaping StatesOverTime) -> Disposable {
        defer {
            primaryDatasource
                .observe { [weak self] in self?.setAndEmitNext(latestPrimaryState: $0) }
                .disposed(by: disposeBag)

            cacheDatasource
                .observe { [weak self] in self?.setAndEmitNext(latestCachedState: $0) }
                .disposed(by: disposeBag)

            loadImpulseEmitter
                .observe { [weak self] in self?.setAndEmitNext(latestLoadImpulse: $0) }
                .disposed(by: disposeBag)
        }

        let disposable = coreDatasource.observe(statesOverTime)
        return CompositeDisposable(disposable, objectToRetain: self)
    }

    private func setAndEmitNext(latestPrimaryState: DatasourceState? = nil,
                                latestCachedState: DatasourceState? = nil,
                                latestLoadImpulse: LoadImpulse<P>? = nil) {

        currentStateComponents.modify { components in
            if let primary = latestPrimaryState {
                components.latestPrimaryState = primary
            }
            if let cached = latestCachedState {
                components.latestCachedState = cached
            }
            if let loadImpulse = latestLoadImpulse {
                components.latestLoadImpulse = loadImpulse
            }
        }

        emitNext()
    }

    private func emitNext() {

        let stateComponents = currentStateComponents.value

        guard let primary = stateComponents.latestPrimaryState,
            let cached = stateComponents.latestCachedState,
            let loadImpulse = stateComponents.latestLoadImpulse,
            shouldSkipLoad(for: loadImpulse) == false else { return }

        let combinedState = self.combinedState(primary: primary, cache: cached, loadImpulse: loadImpulse)

        if currentValue.value != combinedState {
            coreDatasource.emit(combinedState)
        }
    }

    open func combinedState(primary: DatasourceState,
                            cache: DatasourceState,
                            loadImpulse: LoadImpulse<P>) -> DatasourceState {

        switch primary.provisioningState {
        case .notReady, .loading:
            if let primaryValueBox = primary.cacheCompatibleValue(for: loadImpulse) {
                return State.loading(loadImpulse: loadImpulse,
                                     fallbackValueBox: primaryValueBox,
                                     fallbackError: primary.error)
            } else if let cacheValueBox = cache.cacheCompatibleValue(for: loadImpulse) {
                return State.loading(loadImpulse: loadImpulse,
                                     fallbackValueBox: cacheValueBox,
                                     fallbackError: cache.error)
            } else {
                // Neither remote success nor cached value
                switch primary.provisioningState {
                case .notReady, .result: return State.notReady
                // Add primary as fallback so any errors are added
                case .loading: return State.loading(loadImpulse: loadImpulse,
                                                    fallbackValueBox: nil,
                                                    fallbackError: primary.error)
                }
            }
        case .result:
            if let primaryValueBox = primary.cacheCompatibleValue(for: loadImpulse) {
                if primary.hasLoadedSuccessfully {
                    persister?.persist(primary)
                }

                if let error = primary.error {
                    return State.error(error: error,
                                       loadImpulse: loadImpulse,
                                       fallbackValueBox: primaryValueBox)
                } else {
                    return State.value(valueBox: primaryValueBox,
                                       loadImpulse: loadImpulse,
                                       fallbackError: nil)
                }
            } else if let error = primary.error {
                if let cachedValueBox = cache.cacheCompatibleValue(for: loadImpulse) {
                    return State.error(error: error,
                                       loadImpulse: loadImpulse,
                                       fallbackValueBox: cachedValueBox)
                } else {
                    return State.error(error: error,
                                       loadImpulse: loadImpulse,
                                       fallbackValueBox: nil)
                }
            } else {

                // Primary state's loadImpulse's parameters are not cache compatible
                // with the current loadImpulse's parameters. This means that the current
                // primary state must not be shown to the user.
                // This can happen if e.g. an authenticated API request has been made,
                // but the user has logged out in the meantime.
                // Therefore, .notReady is returned, for which views will likely show a
                // loading indicator.
                //
                // Meta: The primary datasource cannot be trusted to send a .loading state
                // for every load impulse it receives. The reliance on the loadImpulseEmitter
                // to provide the current parameters is vital to ensure the provided state is
                // cache-compatible at all times. Else, the view might display
                // old/invalid/unauthorized data.
                return State.notReady
            }
        }
    }

    open func shouldSkipLoad(for loadImpulse: LoadImpulse<P>) -> Bool {
        return loadImpulse.skipIfResultAvailable && currentValue.value.hasLoadedSuccessfully
    }

    public struct StateComponents {
        public var latestPrimaryState: DatasourceState?
        public var latestCachedState: DatasourceState?
        public var latestLoadImpulse: LoadImpulse<P>?

        public static var initial: StateComponents {
            return StateComponents(latestPrimaryState: nil, latestCachedState: nil, latestLoadImpulse: nil)
        }
    }

}

public typealias LoadingStarted = Bool

public extension DatasourceProtocol {

    func cache<Value, P: Parameters, E: DatasourceError>(
        with cacheDatasource: AnyDatasource<ObservedValue>,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
        persister: AnyStatePersister<Value, P, E>? = nil
        ) -> CachedDatasource<Value, P, E> where ObservedValue == State<Value, P, E> {

        return CachedDatasource(
            loadImpulseEmitter: loadImpulseEmitter,
            primaryDatasource: self.any,
            cacheDatasource: cacheDatasource,
            persister: persister
        )
    }
}
