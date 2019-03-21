import Foundation

public extension ObservableProtocol {

    /// Maintains state coming from two sources (self and cacheObservable).
    /// State coming from the primary datasource (self) is treated as
    /// preferential over state from the cache datasource.
    func cachedState<Value, P: ResourceParams, E: ResourceError>(
        cacheObservable: AnyObservable<ObservedValue>,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>)
        -> AnyObservable<ResourceState<Value, P, E>>
        where ObservedValue == ResourceState<Value, P, E> {

            return ValueStream { sendState, disposable in

                let core = CachedDatasourceCore<Value, P, E>()

                disposable += self.observe {
                    core.setAndEmitNext(latestPrimaryState: $0, sendState: sendState)
                }

                disposable += cacheObservable.observe {
                    core.setAndEmitNext(latestCachedState: $0, sendState: sendState)
                }

                disposable += loadImpulseEmitter.observe {
                    core.setAndEmitNext(latestLoadImpulse: $0, sendState: sendState)
                }
            }.any
    }

    /// Persists states sent by `self` and
    func persistState<Value, P: ResourceParams, E: ResourceError>(
        persister: AnyResourceStatePersister<Value, P, E>,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>)
        -> AnyObservable<ResourceState<Value, P, E>>
        where ObservedValue == ResourceState<Value, P, E> {

            let core = PersistStateCore(persister: persister)

            return ValueStream { sendState, disposable in

                disposable += loadImpulseEmitter.observe {
                    core.tryPersist(latestLoadImpulse: $0, sendState: sendState)
                }

                disposable += self.observe {
                    core.tryPersist(state: $0, sendState: sendState)
                    sendState($0)
                }
            }.any
    }

    func persistedCachedState<Value, P: ResourceParams, E: ResourceError>(
        persister: AnyResourceStatePersister<Value, P, E>,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
        cacheLoadError: E)
        -> AnyObservable<ResourceState<Value, P, E>>
        where ObservedValue == ResourceState<Value, P, E> {

            let cacheObservable = ValueStream(loadStatesFromPersister: persister,
                                              loadImpulseEmitter: loadImpulseEmitter,
                                              cacheLoadError: cacheLoadError).any
            let cached = cachedState(cacheObservable: cacheObservable, loadImpulseEmitter: loadImpulseEmitter)
            let persisted = cached.persistState(persister: persister, loadImpulseEmitter: loadImpulseEmitter)
            return persisted
    }

}

public struct CachedDatasourceCore<Value, P: ResourceParams, E: ResourceError> {
    public typealias DatasourceState = ResourceState<Value, P, E>
    public typealias SendState = (DatasourceState) -> Void

    private let currentStateComponents = SynchronizedMutableProperty(StateComponents.initial)

    public init() { }

    public func setAndEmitNext(latestPrimaryState: DatasourceState? = nil,
                               latestCachedState: DatasourceState? = nil,
                               latestLoadImpulse: LoadImpulse<P>? = nil,
                               sendState: SendState) {

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

        emitNext(sendState)
    }

    private func emitNext(_ sendState: SendState) {

        let combinedState = makeCombinedState(currentStateComponents.value)
        sendState(combinedState)
    }

    private func makeCombinedState(_ components: StateComponents) -> DatasourceState {

        guard let loadImpulse = components.latestLoadImpulse else { return .notReady }
        let primary = components.latestPrimaryState
        let cache = components.latestCachedState

        switch primary.provisioningState {
        case .notReady, .loading:
            if let primaryValueBox = primary.cacheCompatibleValue(for: loadImpulse) {
                return ResourceState.loading(
                    loadImpulse: loadImpulse,
                    fallbackValueBox: primaryValueBox,
                    fallbackError: primary.error
                )
            } else if let cacheValueBox = cache.cacheCompatibleValue(for: loadImpulse) {
                return ResourceState.loading(
                    loadImpulse: loadImpulse,
                    fallbackValueBox: cacheValueBox,
                    fallbackError: cache.error
                )
            } else {
                // Neither remote success nor cached value
                switch primary.provisioningState {
                case .notReady, .result:
                    return ResourceState.notReady
                // Add primary as fallback so any errors are added
                case .loading:
                    return ResourceState.loading(
                        loadImpulse: loadImpulse,
                        fallbackValueBox: nil,
                        fallbackError: primary.error
                    )
                }
            }
        case .result:
            if let primaryValueBox = primary.cacheCompatibleValue(for: loadImpulse) {
                if let error = primary.error {
                    return ResourceState.error(
                        error: error,
                        loadImpulse: loadImpulse,
                        fallbackValueBox: primaryValueBox
                    )
                } else {
                    return ResourceState.value(
                        valueBox: primaryValueBox,
                        loadImpulse: loadImpulse,
                        fallbackError: nil
                    )
                }
            } else if let error = primary.error {
                if let cachedValueBox = cache.cacheCompatibleValue(for: loadImpulse) {
                    return ResourceState.error(
                        error: error,
                        loadImpulse: loadImpulse,
                        fallbackValueBox: cachedValueBox
                    )
                } else {
                    return ResourceState.error(
                        error: error,
                        loadImpulse: loadImpulse,
                        fallbackValueBox: nil
                    )
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
                return ResourceState.notReady
            }
        }
    }

    private struct StateComponents {
        var latestPrimaryState: DatasourceState = .notReady
        var latestCachedState: DatasourceState = .notReady
        var latestLoadImpulse: LoadImpulse<P>?

        static var initial: StateComponents {
            return StateComponents(latestPrimaryState: .notReady,
                                   latestCachedState: .notReady,
                                   latestLoadImpulse: nil)
        }
    }

}

public struct PersistStateCore<Value, P: ResourceParams, E: ResourceError> {
    public typealias DatasourceState = ResourceState<Value, P, E>
    public typealias SendState = (DatasourceState) -> Void

    private let currentComponents = SynchronizedMutableProperty(PersistComponents.initial)
    private let persister: AnyResourceStatePersister<Value, P, E>
    private let lastPersistedState = SynchronizedMutableProperty<DatasourceState?>(nil)

    public init(persister: AnyResourceStatePersister<Value, P, E>) {
        self.persister = persister
    }

    public func tryPersist(state: DatasourceState? = nil,
                           latestLoadImpulse: LoadImpulse<P>? = nil,
                           sendState: SendState) {

        currentComponents.modify { components in

            if let state = state {
                components.latestState = state
            }
            if let loadImpulse = latestLoadImpulse {
                components.latestLoadImpulse = loadImpulse
            }

            guard let state = components.latestState,
                let loadImpulse = components.latestLoadImpulse,
                state.hasLoadedSuccessfully(for: loadImpulse) else { return }

            if let lastPersistedState = self.lastPersistedState.value,
                lastPersistedState == state {
                return
            }

            self.lastPersistedState.value = state
            self.persister.persist(state)
        }
    }

    private struct PersistComponents {
        var latestState: ResourceState<Value, P, E>?
        var latestLoadImpulse: LoadImpulse<P>?

        static var initial: PersistComponents {
            return PersistComponents(latestState: nil,
                                     latestLoadImpulse: nil)
        }
    }

}
