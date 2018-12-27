import Foundation

/// Repeats a datasource's last value and/or error, mixed into
/// the latest returned state. E.g. if the original datasource
/// has sent a state with a value and provisioningState == .result,
/// then value is attached to subsequent states as `fallbackValue`
/// until a new state with a value and provisioningState == .result
/// is sent. Same with errors.
///
/// Discussion: A list view is not only interested in the very last
/// state of a datasource, but also in previous ones. E.g. on
/// pull-to-refresh, the original datasource might decide to emit
/// a loading state without a value - which would result in the
/// list view showing an empty view, or a loading view until the
/// next state with a value is sent (same with errors).
/// This struct helps with this by caching the last value and/or
/// error,.
public struct LastResultRetainingDatasource
<Value_: Any, P_: Parameters, E_: DatasourceError>: DatasourceProtocol {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_

    public typealias SubDatasource = AnyDatasource<Value, P, E>
    public typealias LoadImpulseEmitterConcrete = AnyLoadImpulseEmitter<P>

    public let loadsSynchronously = true
    private let innerDatasource: SubDatasource
    private let observableCore = DatasourceObservableCore<Value, P, E>()
    private let disposeBag = DisposeBag()

    public init(innerDatasource: SubDatasource) {
        self.innerDatasource = innerDatasource
    }

    public func observe(_ statesOverTime: @escaping StatesOverTime) -> Disposable {
        defer { startObservingInnerDatasource() }

        // Send .notReady right now, because loadsSynchronously == true
        statesOverTime(DatasourceState.notReady)

        return observableCore.observe(statesOverTime)
    }

    private func startObservingInnerDatasource() {

        var lastState: DatasourceState?
        var lastResult: LastResult?
        innerDatasource.observe { [weak observableCore] state in
            defer { type(of: self).registerStateAsLastResult(state, lastResult: &lastResult) }

            let nextState = type(of: self).nextState(innerState: state, lastResult: lastResult)
            observableCore?.emit(nextState)
        }.disposed(by: disposeBag)
    }

    private static func registerStateAsLastResult(_ state: DatasourceState, lastResult: inout LastResult?) {
        switch state.provisioningState {
        case .loading, .notReady:
            break
        case .result:
            guard let loadImpulse = state.loadImpulse else {
                break
            }

            if value(innerState: state, lastResult: nil, loadImpulse: loadImpulse) != nil {
                lastResult = .value(state)
            } else if error(innerState: state, lastResult: nil, loadImpulse: loadImpulse) != nil {
                lastResult = .error(state)
            }
        }
    }

    private static func nextState(innerState: DatasourceState, lastResult: LastResult?) -> DatasourceState {
        switch innerState.provisioningState {
        case .notReady:
            return DatasourceState.notReady
        case .loading:
            guard let loadImpulse = innerState.loadImpulse else { return .notReady }

            let value = self.value(innerState: innerState, lastResult: lastResult, loadImpulse: loadImpulse)
            let error = self.error(innerState: innerState, lastResult: lastResult, loadImpulse: loadImpulse)
            return DatasourceState.loading(loadImpulse: loadImpulse,
                                           fallbackValue: value,
                                           fallbackError: error)
        case .result:
            guard let loadImpulse = innerState.loadImpulse else { return .notReady }

            if let error = innerState.cacheCompatibleError(for: loadImpulse) {
                let value = self.value(innerState: innerState,
                                       lastResult: lastResult,
                                       loadImpulse: loadImpulse)
                return DatasourceState.error(error: error, loadImpulse: loadImpulse, fallbackValue: value)
            } else if let valueBox = innerState.cacheCompatibleValue(for: loadImpulse) {
                // We have a definitive success result, with no error, so we erase all previous errors
                return DatasourceState.value(value: valueBox.value,
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
    private static func value(innerState: DatasourceState,
                              lastResult: LastResult?,
                              loadImpulse: LoadImpulse<P>) -> Value? {

        if let innerStateValueBox = innerState.cacheCompatibleValue(for: loadImpulse) {
            return innerStateValueBox.value
        } else if let fallbackValueStateValueBox =
            lastResult?.valueState?.cacheCompatibleValue(for: loadImpulse) {
            return fallbackValueStateValueBox.value
        } else {
            return nil
        }
    }

    /// Returns either the current state's error, or the fallbackErrorState's.
    /// If neither is set, returns nil.
    private static func error(innerState: DatasourceState,
                              lastResult: LastResult?,
                              loadImpulse: LoadImpulse<P>) -> E? {

        if let innerStateError = innerState.cacheCompatibleError(for: loadImpulse) {
            return innerStateError
        } else if let fallbackError = lastResult?.errorState?.cacheCompatibleError(for: loadImpulse) {
            return fallbackError
        } else {
            return nil
        }
    }

    private enum LastResult {
        case value(DatasourceState)
        case error(DatasourceState)

        var valueState: DatasourceState? {
            switch self {
            case let .value(value): return value
            case .error: return nil
            }
        }

        var errorState: DatasourceState? {
            switch self {
            case .value: return nil
            case let .error(error): return error
            }
        }
    }

}

public extension DatasourceProtocol {

    typealias LastResultRetaining = LastResultRetainingDatasource<Value, P, E>

    var retainLastResult: LastResultRetaining {
        return LastResultRetaining(innerDatasource: self.any)
    }
}
