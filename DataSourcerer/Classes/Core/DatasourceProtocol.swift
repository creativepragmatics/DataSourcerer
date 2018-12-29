import Foundation

/// Provides or transforms a stream of States.
/// Should only start work after `observe(_)` is first called.
/// Must either synchronously return a value upon subscription to `state`,
/// or return `false` for `loadsSynchronously`.
public protocol DatasourceProtocol {
    associatedtype Value: Any
    associatedtype P: Parameters
    associatedtype E: DatasourceError
    typealias DatasourceState = State<Value, P, E>
    typealias StatesOverTime = (DatasourceState) -> Void

    /// Register an observer for the states produces by the
    /// datasource.
    func observe(_ statesOverTime: @escaping StatesOverTime) -> Disposable

    /// Must return `true` if the datasource sends a `state`
    /// immediately on subscription.
    var loadsSynchronously: Bool { get }
}

public extension DatasourceProtocol {
    var any: AnyDatasource<Value, P, E> {
        return AnyDatasource(self)
    }
}

public struct AnyDatasource<Value_, P_: Parameters, E_: DatasourceError>: DatasourceProtocol {

    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_

    private let _observe: (@escaping StatesOverTime) -> Disposable
    public let loadsSynchronously: Bool

    init<D: DatasourceProtocol>(_ datasource: D) where D.DatasourceState == DatasourceState {
        self._observe = datasource.observe
        self.loadsSynchronously = datasource.loadsSynchronously
    }

    public func observe(_ statesOverTime: @escaping StatesOverTime) -> Disposable {
        return _observe(statesOverTime)
    }

}

public protocol DatasourceError: Error, Equatable {

    var errorMessage: DatasourceErrorMessage { get }
}

public enum DatasourceErrorMessage: Equatable, Codable {
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

public protocol CachedDatasourceError: DatasourceError {

    init(cacheLoadError type: DatasourceErrorMessage)
}

public typealias StateObservable<Value, P: Parameters, E: DatasourceError> =
    DefaultObservable<State<Value, P, E>>
