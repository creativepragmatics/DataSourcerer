import Foundation

public extension ObservableProtocol {

    /// Repeats a datasource's latest value and/or error, mixed into
    /// the latest returned state. E.g. if the original datasource
    /// has sent a state with a value and provisioningState == .result,
    /// then value is attached to subsequent states as `fallbackValue`
    /// until a new state with a value and provisioningState == .result
    /// is sent. Same with errors.
    ///
    /// Discussion: A view is probably not only interested in the very latest
    /// state of a datasource, but also in previous ones. E.g. on
    /// pull-to-refresh, the original datasource might decide to emit
    /// a loading state without a value - which would result in the
    /// list view showing an empty view, or a loading view until the
    /// next state with a value is sent (same with errors).
    /// This struct helps with this by caching the latest value and/or
    /// error.
    ///
    /// Some scenarios for input state sequences and what output state they will
    /// yield (S = Success, E = Error, L = Loading, NR = NotReady):
    ///
    /// INPUT SEQUENCE      OUTPUT STATE
    /// --------------------------------------------------------------------------
    /// S > L:              Loading with fallback value from S
    /// E > L:              Loading with fallback error from E
    /// S > E > L:          Loading with fallback error from E
    /// S1 > E > S2 > L:    Loading with fallback value from S2
    /// S > E > NR > L:     Loading without any fallbacks (NR causes disruption)
    /// E1 > E2 > L:        Loading with fallback error from E2
    /// E > S:              Success without any fallbacks
    /// E > NR > S:         Success without any fallbacks
    /// S > E:              Error with fallback value from S
    /// S1 > S2:            Success with value from S2
    /// E1 > E2:            Error with error from E2
    func rememberLatestSuccessAndError<Value, P: ResourceParams, E: ResourceError>()
        -> AnyObservable<ObservedValue> where ObservedValue == ResourceState<Value, P, E> {

            return ValueStream { sendState, disposable in

                let core = LatestSuccessAndErrorRememberingCore<Value, P, E>()

                disposable += self.observe { state in
                    core.setAndEmitNext(receivedState: state, sendState: sendState)
                }
            }.any
    }

}

// TODO Test with various state sequences (see comment @
// rememberLatestSuccessAndError)
public final class LatestSuccessAndErrorRememberingCore
<Value_: Any, P_: ResourceParams, E_: ResourceError> {

    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias State = ResourceState<Value, P, E>
    public typealias SendState = (State) -> Void

    // Holds the latest result that was sent by the Observable.
    private let latestResult = SynchronizedMutableProperty<LatestResult>(.none)

    public init() {}

    public func setAndEmitNext(receivedState: State,
                               sendState: SendState) {

        sendState(nextState(state: receivedState))

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
                latestResult.value = .error(LatestError(params: loadImpulse.params, error: error))
            } else if let successValue = receivedState.cacheCompatibleValue(for: loadImpulse) {
                let latestSuccess = LatestSuccessValue(params: loadImpulse.params, value: successValue)
                latestResult.value = .successValue(latestSuccess)
            } else {
                // A result state that has neither a cacheCompatible success nor error,
                // is likely invalid. We therefore wipe both latest values.
                latestResult.value = .none
            }
        }
    }

    private func nextState(state: State) -> State {
        switch state.provisioningState {
        case .notReady:
            return State.notReady
        case .loading:
            guard let loadImpulse = state.loadImpulse else { return .notReady }

            switch self.latestResult.value {
            case let .successValue(successValue) where successValue.params.isCacheCompatible(loadImpulse.params):
                return State.loading(loadImpulse: loadImpulse,
                                     fallbackValueBox: successValue.value,
                                     fallbackError: nil)
            case let .error(error) where error.params.isCacheCompatible(loadImpulse.params):
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
                // We have a definitive success result, with no error, so we erase all previous errors
                return State.value(valueBox: successValue,
                                             loadImpulse: loadImpulse,
                                             fallbackError: nil)
            } else {
                // Latest state might not match current parameters - return .notReady
                // so all cached data is purged. This can happen if e.g. an authenticated API
                // request has been made, but the user has logged out in the meantime. The result
                // must be discarded or the next logged in user might see the previous user's data.
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
        let params: P
        let value: EquatableBox<Value>
    }

    public struct LatestError: Equatable {
        let params: P
        let error: E
    }

}
