import Foundation

/// Maintains state coming from multiple sources (primary and cache).
/// It is able to support pagination, live feeds, etc in the primary datasource (yet to be implemented).
/// State coming from the primary datasource is treated as preferential over state from
/// the cache datasource. You can think of the cache datasource as cache.
open class CachedDatasource<Value_, P_: Parameters, E_: DatasourceError>: DatasourceProtocol {

    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias SubDatasource = AnyDatasource<Value, P, E>
    public typealias StatePersisterConcrete = AnyStatePersister<Value, P, E>

    public var lastValue: SynchronizedProperty<DatasourceState?> {
        return innerObservable.lastValue
    }
    public let loadsSynchronously = true
    public let loadImpulseEmitter: AnyLoadImpulseEmitter<P>

    private let primaryDatasource: SubDatasource
    private let cacheDatasource: SubDatasource
    private let persister: StatePersisterConcrete?
    private let innerObservable = InnerStateObservable<Value, P, E>()
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

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
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

        // Send .notReady right now, because loadsSynchronously == true
        statesOverTime(DatasourceState.notReady)

        return innerObservable.observe(statesOverTime)
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

        let stateChanged: Bool = {
            let lastState = lastValue.value
            if let lastState = lastState, lastState != combinedState {
                return true
            } else {
                return lastState == nil
            }
        }()

        if stateChanged {
            innerObservable.emit(combinedState)
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
            if primary.hasLoadedSuccessfully {
                persister?.persist(primary)
            }

            if let primaryValueBox = primary.cacheCompatibleValue(for: loadImpulse) {
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
                // Remote state might not match current parameters - return .notReady
                // so all cached data is purged. This can happen if e.g. an authenticated API
                // request has been made, but the user has logged out in the meantime. The result
                // must be discarded or the next logged in user might see the previous user's data.
                return State.notReady
            }
        }
    }

    open func shouldSkipLoad(for loadImpulse: LoadImpulse<P>) -> Bool {
        return loadImpulse.skipIfResultAvailable && (lastValue.value?.hasLoadedSuccessfully ?? false)
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
