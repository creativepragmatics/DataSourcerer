import Foundation

/// Provides or transforms a stream of States.
///
/// Must only start work after `observe(_)` is first called AND
/// `loadImpulseEmitter` has sent the first impulse.
///
/// Analogy to ReactiveSwift: Datasources are like SignalProducers,
/// which are "cold" (no work performed) until they are started.
/// Instead of a start() function, datasources require the first
/// load impulse. One major difference to SignalProducers is that
/// datasources don't restart if `observe(_)` is called again.
///
/// Analogy to RxSwift/ReactiveX: Datasources are like cold Observables
/// (e.g. "Just") that only start work
/// (no work performed) until it is started. Instead of a start()
/// function, datasources require the first load impulse.
public protocol DatasourceProtocol: StatefulObservable where ObservedValue == DatasourceState {
    associatedtype Value: Any
    associatedtype P: Parameters
    associatedtype E: DatasourceError
    typealias DatasourceState = State<Value, P, E>
    typealias StatesOverTime = ValuesOverTime

    /// Emits loading impulses that prompt the datasource to do
    /// work. The datasource must subscribe to the loadImpulseEmitter,
    /// at least to listen for the first impulse to start work.
    ///
    /// From a technical point of view, this property requirement is
    /// superfluous, but it helps the easier nesting of datasources
    /// and end-user (=developer) convenience.
    var loadImpulseEmitter: AnyLoadImpulseEmitter<P> { get }
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

    public let currentValue: SynchronizedProperty<State<Value, P, E>>
    public var loadImpulseEmitter: AnyLoadImpulseEmitter<P>

    private let _observe: (@escaping StatesOverTime) -> Disposable
    private let _removeObserver: (Int) -> Void

    init<D: DatasourceProtocol>(_ datasource: D) where D.DatasourceState == DatasourceState {
        self.currentValue = datasource.currentValue
        self.loadImpulseEmitter = datasource.loadImpulseEmitter
        self._observe = datasource.observe
        self._removeObserver = datasource.removeObserver
    }

    public func observe(_ statesOverTime: @escaping StatesOverTime) -> Disposable {
        return _observe(statesOverTime)
    }

    public func removeObserver(with key: Int) {
        _removeObserver(key)
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

public typealias InnerStateObservable<Value, P: Parameters, E: DatasourceError> =
    DefaultStatefulObservable<State<Value, P, E>>
