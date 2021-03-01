import Foundation
import ReactiveSwift

public extension Resource {
    struct CacheReader {
        public let getCachedState: (LoadImpulse) -> SignalProducer<State, Never>
    }

    struct CachePersister {
        public let persistCachedState: (State) -> SignalProducer<Never, Never>
    }

    struct Cache {
        public let reader: CacheReader
        public let persister: CachePersister
    }
}

public extension SignalProducer {

    func combineWithCachedStates<ResourceValue, Query: Cacheable, Failure: Equatable>(
        from cacheReader: Resource<ResourceValue, Query, Failure>.CacheReader
    ) -> SignalProducer
    where Value == Resource<ResourceValue, Query, Failure>.State, Error == Never {
        let upstreamStates = replayLazily(upTo: 1)
        let loadImpulsesForCache = upstreamStates
            .map(\.loadImpulse)
            .skipRepeats()
            .skipNil()
        let cachedStates = loadImpulsesForCache
            .flatMap(.latest, cacheReader.getCachedState)
            .prefix(value: .notReady)
        return upstreamStates
            .combineLatest(with: cachedStates)
            .map { upstreamState, cachedState -> Value in
                guard let loadImpulse = upstreamState.loadImpulse else {
                    return upstreamState
                }
                return upstreamState.combineUpstream(
                    withCached: cachedState,
                    loadImpulse: loadImpulse
                )
            }
    }

    func persist<ResourceValue, Query: Cacheable, Failure: Equatable>(
        with cachePersister: Resource<ResourceValue, Query, Failure>.CachePersister
    ) -> SignalProducer
    where Value == Resource<ResourceValue, Query, Failure>.State, Error == Never {
        flatMap(.latest) { state -> SignalProducer in
            cachePersister
                .persistCachedState(state)
                .promoteValue(Value.self)
                .concat(value: state)
        }
    }
}

private extension Resource.State {
    func combineUpstream(
        withCached cachedState: Self,
        loadImpulse: Resource.LoadImpulse
    ) -> Self {
        switch provisioningState {
        case .notReady, .loading:
            if let upstreamValueBox = cacheCompatibleValue(for: loadImpulse) {
                return .loading(
                    loadImpulse: loadImpulse,
                    fallbackValueBox: upstreamValueBox,
                    fallbackError: error
                )
            } else if let cacheValueBox = cachedState.cacheCompatibleValue(for: loadImpulse) {
                return .loading(
                    loadImpulse: loadImpulse,
                    fallbackValueBox: cacheValueBox,
                    fallbackError: cachedState.error
                )
            } else {
                // Neither upstream success nor cached value
                switch provisioningState {
                case .notReady, .result:
                    return .notReady
                // Add upstream as fallback so any errors are added
                case .loading:
                    return .loading(
                        loadImpulse: loadImpulse,
                        fallbackValueBox: nil,
                        fallbackError: error
                    )
                }
            }
        case .result:
            if let upstreamValueBox = cacheCompatibleValue(for: loadImpulse) {
                if let error = error {
                    return .error(
                        error: error,
                        loadImpulse: loadImpulse,
                        fallbackValueBox: upstreamValueBox
                    )
                } else {
                    return .value(
                        valueBox: upstreamValueBox,
                        loadImpulse: loadImpulse,
                        fallbackError: nil
                    )
                }
            } else if let error = error {
                if let cachedValueBox = cachedState.cacheCompatibleValue(for: loadImpulse) {
                    return .error(
                        error: error,
                        loadImpulse: loadImpulse,
                        fallbackValueBox: cachedValueBox
                    )
                } else {
                    return .error(
                        error: error,
                        loadImpulse: loadImpulse,
                        fallbackValueBox: nil
                    )
                }
            } else {
                // Upstream state's loadImpulse's parameters are not cache compatible
                // with the current loadImpulse's parameters. This means that the current
                // upstream state must not be shown to the user.
                // This can happen if e.g. an authenticated API request has been made,
                // but the user has logged out in the meantime.
                // Therefore, .notReady is returned, for which views will likely show a
                // loading indicator.
                //
                // Meta: The upstream datasource cannot be trusted to send a .loading state
                // for every load impulse it receives. The reliance on the loadImpulseEmitter
                // to provide the current parameters is vital to ensure the provided state is
                // cache-compatible at all times. Else, the view might display
                // old/invalid/unauthorized data.
                return .notReady
            }
        }
    }
}
