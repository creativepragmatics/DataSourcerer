import Foundation

/// Provides or transforms a stream of States.
///
/// Must only start work after `observe(_)` is first called AND
/// `loadImpulseEmitter` has sent the first impulse.
///
/// Per definition of StatefulObservable, the current value is
/// emitted synchronously to an observer when it calls `observe(_)`.
///
/// Analogy to ReactiveSwift: Datasources are like SignalProducers,
/// which are "cold" (no work performed) until they are started.
/// Instead of a start() function, datasources require the first
/// load impulse. One major difference to SignalProducers is that
/// datasources don't restart if `observe(_)` is called again.
/// In terms of values sent, Datasources behave very much like
/// ReactivewSwift.Property.signalProducer or
/// SignalProducer.replayLazily(1).
///
/// Analogy to RxSwift/ReactiveX: Insert example :)
public protocol DatasourceProtocol: StatefulObservable where ObservedValue == DatasourceState {
    associatedtype Value: Any
    associatedtype P: Parameters
    associatedtype E: DatasourceError
    typealias DatasourceState = State<Value, P, E>
    typealias StatesOverTime = ValuesOverTime
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

public typealias InnerStateObservable<Value, P: Parameters, E: DatasourceError> =
    DefaultStatefulObservable<State<Value, P, E>>
