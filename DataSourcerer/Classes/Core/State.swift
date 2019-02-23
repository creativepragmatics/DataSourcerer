import Foundation

/// Originally an enum, State is a struct to provide maximal flexibility,
/// and remove any semantic annotations of value and error.
public struct State<Value, P: Parameters, E: StateError>: Equatable {

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
    static func error(error: E,
                      loadImpulse: LoadImpulse<P>,
                      fallbackValueBox: EquatableBox<Value>?) -> State {
        return State(provisioningState: .result,
                     loadImpulse: loadImpulse,
                     value: fallbackValueBox,
                     error: error)
    }

    /// A value has been created in a datasource. An error can still be defined
    /// (e.g. a cached value has been found, but )
    static func value(valueBox: EquatableBox<Value>,
                      loadImpulse: LoadImpulse<P>,
                      fallbackError: E?) -> State {
        return State(provisioningState: .result,
                     loadImpulse: loadImpulse,
                     value: valueBox,
                     error: fallbackError)
    }

    /// The emitting datasource is loading, and has a fallbackValue (e.g. from a cache), or
    /// a fallback error, or both.
    static func loading(loadImpulse: LoadImpulse<P>,
                        fallbackValueBox: EquatableBox<Value>?,
                        fallbackError: E?) -> State {
        return State(provisioningState: .loading,
                     loadImpulse: loadImpulse,
                     value: fallbackValueBox,
                     error: fallbackError)
    }

    func hasLoadedSuccessfully(for loadImpulse: LoadImpulse<P>) -> Bool {
        switch provisioningState {
        case .loading, .notReady:
            return false
        case .result:
            if cacheCompatibleValue(for: loadImpulse) != nil {
                return error == nil
            } else {
                return false
            }
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

extension State: Codable where Value: Codable, P: Codable, E: Codable {}

public protocol StateError: Error, Equatable {

    var errorMessage: StateErrorMessage { get }

    init(message: StateErrorMessage)
}

public struct NoStateError: StateError {

    public var errorMessage: StateErrorMessage { return .default }

    public init(message: StateErrorMessage) {}
}

public enum StateErrorMessage: Equatable, Codable {
    case `default`
    case message(String)

    enum CodingKeys: String, CodingKey {
        case enumCaseKey = "type"
        case `default`
        case message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let enumCaseString = try container.decode(String.self, forKey: .enumCaseKey)
        guard let enumCase = CodingKeys(rawValue: enumCaseString) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown enum case '\(enumCaseString)'"
                )
            )
        }

        switch enumCase {
        case .default:
            self = .default
        case .message:
            if let message = try? container.decode(String.self, forKey: .message) {
                self = .message(message)
            } else {
                self = .default
            }
        default: throw DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown enum case '\(enumCase)'")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .message(message):
            try container.encode(CodingKeys.message.rawValue, forKey: .enumCaseKey)
            try container.encode(message, forKey: .message)
        case .default:
            try container.encode(CodingKeys.default.rawValue, forKey: .enumCaseKey)
        }
    }
}
