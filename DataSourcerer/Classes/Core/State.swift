import Foundation

/// Originally an enum, State is a struct to provide maximal flexibility,
/// and remove any semantic annotations of value and error.
public struct State<Value_, P_: Parameters, E_: DatasourceError>: Equatable {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_

    public var provisioningState: ProvisioningState
    public var loadImpulse: LoadImpulse<P>?
    public var value: EquatableBox<Value>?
    public var error: E?

}

public extension State {

    /// Datasource is not ready to provide data.
    static var notReady: State {
        return State(provisioningState: .notReady, loadImpulse: nil, value: nil, error: nil)
    }

    /// An error has been encountered in a datasource (e.g. while loading).
    /// A value can still be defined (e.g. API call failed, but a cache value is
    /// available).
    static func error(error: E, loadImpulse: LoadImpulse<P>, fallbackValueBox: EquatableBox<Value>?) -> State {
        return State(provisioningState: .result,
                     loadImpulse: loadImpulse,
                     value: fallbackValueBox,
                     error: error)
    }

    /// A value has been created in a datasource. An error can still be defined
    /// (e.g. a cached value has been found, but )
    static func value(valueBox: EquatableBox<Value>, loadImpulse: LoadImpulse<P>, fallbackError: E?) -> State {
        return State(provisioningState: .result,
                     loadImpulse: loadImpulse,
                     value: valueBox,
                     error: fallbackError)
    }

    /// The emitting datasource is loading, and has a fallbackValue (e.g. from a cache), or
    /// a fallback error, or both.
    static func loading(loadImpulse: LoadImpulse<P>, fallbackValueBox: EquatableBox<Value>?, fallbackError: E?) -> State {
        return State(provisioningState: .loading,
                     loadImpulse: loadImpulse,
                     value: fallbackValueBox,
                     error: fallbackError)
    }

    var hasLoadedSuccessfully: Bool {
        switch provisioningState {
        case .loading, .notReady:
            return false
        case .result:
            return value?.value != nil && error == nil
        }
    }

    func cacheCompatibleValue(for loadImpulse: LoadImpulse<P>) -> EquatableBox<Value>? {
        guard let value = self.value,
            let selfLoadImpulse = self.loadImpulse,
            selfLoadImpulse.isCacheCompatible(loadImpulse) else {
                return nil
        }
        return value
    }

    func cacheCompatibleError(for loadImpulse: LoadImpulse<P>) -> E? {
        guard let error = self.error,
            let selfLoadImpulse = self.loadImpulse,
            selfLoadImpulse.isCacheCompatible(loadImpulse) else {
                return nil
        }
        return error
    }

}

/// Type Int because it gives Equatable and Codable conformance for free
public enum ProvisioningState: Int, Equatable, Codable {
    case notReady
    case loading
    case result
}

extension State: Codable where Value_: Codable, P_: Codable, E_: Codable {}
