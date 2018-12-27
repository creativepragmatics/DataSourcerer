import Foundation

/// Maintains state coming from multiple sources (primary and cache).
/// It is able to support pagination, live feeds, etc in the primary datasource (yet to be implemented).
/// State coming from the primary datasource is treated as preferential over state from
/// the cache datasource. You can think of the cache datasource as cache.
public class CachedDatasource<Value_, P_: Parameters, E_: DatasourceError>: DatasourceProtocol {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    
    public typealias SubDatasource = AnyDatasource<Value, P, E>
    public typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<P>
    public typealias StatePersisterConcrete = AnyStatePersister<Value, P, E>
    
    private let primaryDatasource: SubDatasource
    private let cacheDatasource: SubDatasource
    private let loadImpulseEmitter: LoadImpulseEmitterConcrete
    private let persister: StatePersisterConcrete?
    
    public let loadsSynchronously = true
    
    private let observableCore = DatasourceObservableCore<Value, P, E>()
    private let disposeBag = DisposeBag()
    
    private var currentStateComponents = SynchronizedProperty(StateComponents.initial)
    
    private var currentState = SynchronizedProperty(DatasourceState.notReady)
    
    public init(loadImpulseEmitter: LoadImpulseEmitterConcrete,
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
        
        // Send .notReady right now, because loadsSynchronously == true
        statesOverTime(DatasourceState.notReady)
        
        return observableCore.observe(statesOverTime)
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
        currentState.value = combinedState
        observableCore.emit(combinedState)
    }
    
    open func combinedState(primary: DatasourceState, cache: DatasourceState, loadImpulse: LoadImpulse<P>) -> DatasourceState {
        
        switch primary.provisioningState {
        case .notReady, .loading:
            if let primaryValueBox = primary.cacheCompatibleValue(for: loadImpulse) {
                return State.loading(loadImpulse: loadImpulse, fallbackValue: primaryValueBox.value, fallbackError: primary.error)
            } else if let cacheValueBox = cache.cacheCompatibleValue(for: loadImpulse) {
                return State.loading(loadImpulse: loadImpulse, fallbackValue: cacheValueBox.value, fallbackError: cache.error)
            } else {
                // Neither remote success nor cachely cached value
                switch primary.provisioningState {
                case .notReady, .result: return State.notReady
                // Add primary as fallback so any errors are added
                case .loading: return State.loading(loadImpulse: loadImpulse, fallbackValue: nil, fallbackError: primary.error)
                }
            }
        case .result:
            if primary.hasLoadedSuccessfully {
                persister?.persist(primary)
            }
            
            if let primaryValueBox = primary.cacheCompatibleValue(for: loadImpulse) {
                if let error = primary.error {
                    return State.error(error: error, loadImpulse: loadImpulse, fallbackValue: primaryValueBox.value)
                } else {
                    return State.value(value: primaryValueBox.value, loadImpulse: loadImpulse, fallbackError: nil)
                }
            } else if let error = primary.error {
                if let cachedValueBox = cache.cacheCompatibleValue(for: loadImpulse) {
                    return State.error(error: error, loadImpulse: loadImpulse, fallbackValue: cachedValueBox.value)
                } else {
                    return State.error(error: error, loadImpulse: loadImpulse, fallbackValue: nil)
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
        return loadImpulse.skipIfResultAvailable && currentState.value.hasLoadedSuccessfully
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

//public extension DatasourceProtocol {
//
//    public func cached(with cacheDatasource: AnyDatasource<State>, loadImpulseEmitter: AnyLoadImpulseEmitter<State.P, State.LIT>, persister: AnyStatePersister<State>?) -> CachedDatasource<State> {
//        return CachedDatasource<State>.init(loadImpulseEmitter: loadImpulseEmitter, primaryDatasource: self.any, cacheDatasource: cacheDatasource, persister: persister)
//    }
//}
