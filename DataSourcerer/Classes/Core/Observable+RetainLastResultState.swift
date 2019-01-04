import Foundation

public extension ObservableProtocol {

    /// Repeats a datasource's last value and/or error, mixed into
    /// the latest returned state. E.g. if the original datasource
    /// has sent a state with a value and provisioningState == .result,
    /// then value is attached to subsequent states as `fallbackValue`
    /// until a new state with a value and provisioningState == .result
    /// is sent. Same with errors.
    ///
    /// Discussion: A view is probably not only interested in the very last
    /// state of a datasource, but also in previous ones. E.g. on
    /// pull-to-refresh, the original datasource might decide to emit
    /// a loading state without a value - which would result in the
    /// list view showing an empty view, or a loading view until the
    /// next state with a value is sent (same with errors).
    /// This struct helps with this by caching the last value and/or
    /// error.
    func retainLastResultState<Value, P: Parameters, E: StateError>()
        -> AnyObservable<ObservedValue> where ObservedValue == State<Value, P, E> {

            return Datasource { sendState, disposable in

                let core = LastResultRetainingCore<Value, P, E>()

                disposable += self.observe { state in
                    core.setAndEmitNext(sourceState: state, sendState: sendState)
                }
            }.any
    }
}

public final class LastResultRetainingCore
<Value_: Any, P_: Parameters, E_: StateError> {

    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias DatasourceState = State<Value, P, E>
    public typealias SendState = (DatasourceState) -> Void

    private let lastResult = SynchronizedMutableProperty<LastResult?>(nil)

    public init() { }

    public func setAndEmitNext(sourceState: DatasourceState,
                               sendState: SendState) {

        sendState(nextState(state: sourceState))

        // Set lastResult if a matching value or error is contained
        // in state.
        switch sourceState.provisioningState {
        case .loading, .notReady:
            break
        case .result:
            guard let loadImpulse = sourceState.loadImpulse else {
                break
            }

            if self.value(state: sourceState, loadImpulse: loadImpulse) != nil {
                self.lastResult.value = .value(sourceState)
            } else if self.error(state: sourceState, loadImpulse: loadImpulse) != nil {
                self.lastResult.value = .error(sourceState)
            } else {
                self.lastResult.value = nil
            }
        }
    }

    private func nextState(state: DatasourceState) -> DatasourceState {
        switch state.provisioningState {
        case .notReady:
            return DatasourceState.notReady
        case .loading:
            guard let loadImpulse = state.loadImpulse else { return .notReady }

            let valueBox = self.value(state: state, loadImpulse: loadImpulse)
            let error = self.error(state: state, loadImpulse: loadImpulse)
            return DatasourceState.loading(loadImpulse: loadImpulse,
                                           fallbackValueBox: valueBox,
                                           fallbackError: error)
        case .result:
            guard let loadImpulse = state.loadImpulse else { return .notReady }

            if let error = state.cacheCompatibleError(for: loadImpulse) {
                let valueBox = self.value(state: state, loadImpulse: loadImpulse)
                return DatasourceState.error(error: error,
                                             loadImpulse: loadImpulse,
                                             fallbackValueBox: valueBox)
            } else if let valueBox = state.cacheCompatibleValue(for: loadImpulse) {
                // We have a definitive success result, with no error, so we erase all previous errors
                return DatasourceState.value(valueBox: valueBox,
                                             loadImpulse: loadImpulse,
                                             fallbackError: nil)
            } else {
                // Latest state might not match current parameters - return .notReady
                // so all cached data is purged. This can happen if e.g. an authenticated API
                // request has been made, but the user has logged out in the meantime. The result
                // must be discarded or the next logged in user might see the previous user's data.
                return DatasourceState.notReady
            }
        }
    }

    /// Returns either the current state's value, or the fallbackValueState's.
    /// If neither is set, returns nil.
    private func value(state: DatasourceState,
                       loadImpulse: LoadImpulse<P>) -> EquatableBox<Value>? {

        if let innerStateValueBox = state.cacheCompatibleValue(for: loadImpulse) {
            return innerStateValueBox
        } else if let fallbackValueStateValueBox =
            lastResult.value?.valueState?.cacheCompatibleValue(for: loadImpulse) {
            return fallbackValueStateValueBox
        } else {
            return nil
        }
    }

    /// Returns either the current state's error, or the fallbackErrorState's.
    /// If neither is set, returns nil.
    private func error(state: DatasourceState,
                       loadImpulse: LoadImpulse<P>) -> E? {

        if let innerStateError = state.cacheCompatibleError(for: loadImpulse) {
            return innerStateError
        } else if let fallbackError = lastResult.value?.errorState?.cacheCompatibleError(for: loadImpulse) {
            return fallbackError
        } else {
            return nil
        }
    }

    public enum LastResult {
        case value(DatasourceState)
        case error(DatasourceState)

        var valueState: DatasourceState? {
            switch self {
            case let .value(value) where value.value != nil: return value
            default: return nil
            }
        }

        var errorState: DatasourceState? {
            switch self {
            case let .error(error) where error.error != nil: return error
            default: return nil
            }
        }
    }

}
