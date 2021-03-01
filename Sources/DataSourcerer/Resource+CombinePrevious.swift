import ReactiveSwift

public extension SignalProducer {

    /// Repeats a datasource's latest value and/or error, mixed into
    /// the latest returned state. E.g. if the original datasource
    /// has sent a state with a value and provisioningState == .result,
    /// then value is attached to subsequent states as `fallbackValue`
    /// until a new state with a value and provisioningState == .result
    /// is sent. Same with errors.
    ///
    /// Motivation: A view is probably not only interested in the very
    /// latest state of a datasource, but also in previous ones.
    /// E.g. on pull-to-refresh, the original datasource might decide
    /// to emit a loading state without a value - which would result
    /// in the list view showing an empty view, or a loading view until
    /// the next state with a value is sent (same with errors).
    /// This method helps with this by caching the latest value and/or
    /// error.
    ///
    /// Some scenarios for input state sequences and what output state they will
    /// yield (S = Success, E = Error, L = Loading, NR = NotReady):
    ///
    ///     INPUT SEQUENCE     |  OUTPUT STATE
    ///     -------------------+----------------------------------------------------
    ///     S > L:             | Loading with fallback value from S
    ///     E > L:             | Loading with fallback error from E
    ///     S > E > L:         | if preferFallbackValueOverFallbackError:
    ///                        |   Loading with fallback value from S
    ///                        | else
    ///                        |   Loading with fallback error from E
    ///     S1 > E > S2 > L:   | Loading with fallback value from S2
    ///     S > E > NR > L:    | Loading without any fallbacks (NR causes disruption)
    ///     E1 > E2 > L:       | Loading with fallback error from E2
    ///     E > S:             | Success without any fallbacks
    ///     E > NR > S:        | Success without any fallbacks
    ///     S > E:             | Error with fallback value from S
    ///     S1 > S2:           | Success with value from S2
    ///     E1 > E2:           | Error with error from E2
    ///
    /// - Parameter preferFallbackValueOverFallbackError: See table above (3. line)
    ///     how this parameter affects behavior
    /// - Returns: A `SignalProducer` sending values according to the aforementioned
    ///     behavior.
    func combinePrevious<ResourceValue, Q: Cacheable, F>(
        preferFallbackValueOverFallbackError: Bool
    ) -> SignalProducer
    where Value == Resource<ResourceValue, Q, F>.State, Error == Never {
        let core = Resource<ResourceValue, Q, F>.CombinePreviousCore(
            preferFallbackValueOverFallbackError: preferFallbackValueOverFallbackError
        )
        return flatMap(.latest) {
            SignalProducer(value: core.map(receivedState: $0))
        }
    }
}

private extension Resource {
    final class CombinePreviousCore {
        typealias SendState = (Resource.State) -> Void

        // Holds the latest result that was sent by the Observable.
        private let latestResult = MutableProperty<LatestResult>(.none)
        private let preferFallbackValueOverFallbackError: Bool

        public init(preferFallbackValueOverFallbackError: Bool) {
            self.preferFallbackValueOverFallbackError =
                preferFallbackValueOverFallbackError
        }

        public func map(
            receivedState: Resource.State
        ) -> Resource.State {
            let nextState = makeNextState(for: receivedState)

            // Set latestResult if a result is contained
            // in observed state. Set latestSuccessValue if a value is
            // contained.
            switch receivedState.provisioningState {
            case .loading:
                break
            case .notReady:
                // Remove latest results because we don't want a previous result show
                // up after this point
                latestResult.value = .none
            case .result:
                guard let loadImpulse = receivedState.loadImpulse else {
                    latestResult.value = .none
                    break
                }

                if let error = receivedState.cacheCompatibleError(for: loadImpulse) {
                    switch latestResult.value {
                    case .successValue where preferFallbackValueOverFallbackError:
                        break
                    case .none, .error, .successValue:
                        latestResult.value = .error(
                            LatestError(query: loadImpulse.query, error: error)
                        )
                    }
                } else if let successValue = receivedState
                            .cacheCompatibleValue(for: loadImpulse) {
                    let latestSuccess = LatestSuccessValue(
                        query: loadImpulse.query,
                        value: successValue
                    )
                    latestResult.value = .successValue(latestSuccess)
                } else {
                    // A result state that has neither a cacheCompatible success nor error,
                    // is likely invalid. We therefore wipe both latest values.
                    latestResult.value = .none
                }
            }

            return nextState
        }

        private func makeNextState(for state: State) -> State {
            switch state.provisioningState {
            case .notReady:
                return State.notReady
            case .loading:
                guard let loadImpulse = state.loadImpulse else { return .notReady }

                if let valueBox = state.value {
                    return State.loading(loadImpulse: loadImpulse,
                                         fallbackValueBox: valueBox,
                                         fallbackError: nil)
                }

                switch self.latestResult.value {
                case let .successValue(successValue) where
                        successValue.query.isCacheCompatible(to: loadImpulse.query):
                    return State.loading(loadImpulse: loadImpulse,
                                         fallbackValueBox: successValue.value,
                                         fallbackError: nil)
                case let .error(error)
                        where error.query.isCacheCompatible(to: loadImpulse.query):
                    return State.loading(loadImpulse: loadImpulse,
                                         fallbackValueBox: nil,
                                         fallbackError: error.error)
                case .successValue, .error, .none:
                    return State.loading(loadImpulse: loadImpulse,
                                         fallbackValueBox: nil,
                                         fallbackError: nil)
                }
            case .result:
                guard let loadImpulse = state.loadImpulse else { return .notReady }

                if let error = state.cacheCompatibleError(for: loadImpulse) {
                    switch latestResult.value {
                    case let .successValue(successValue):
                        return State.error(error: error,
                                           loadImpulse: loadImpulse,
                                           fallbackValueBox: successValue.value)
                    case .error, .none:
                        return state
                    }
                } else if let successValue = state.cacheCompatibleValue(for: loadImpulse) {
                    // We have a definitive success result, with no error, so we erase
                    // all previous errors.
                    return State.value(
                        valueBox: successValue,
                        loadImpulse: loadImpulse,
                        fallbackError: nil
                    )
                } else {
                    // Latest state might not match current parameters - return
                    // .notReady so all cached data is purged. This can happen if e.g. an
                    // authenticated API request has been made, but the user has logged out
                    // in the meantime. The result must be discarded or the next logged in
                    // user might see the previous user's data.
                    return State.notReady
                }
            }
        }

        public enum LatestResult: Equatable {
            case none
            case successValue(LatestSuccessValue)
            case error(LatestError)
        }

        public struct LatestSuccessValue: Equatable {
            let query: Query
            let value: EquatableBox<Value>
        }

        public struct LatestError: Equatable {
            let query: Query
            let error: Failure
        }
    }
}
