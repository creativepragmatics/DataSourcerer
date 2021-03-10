import Foundation
import ReactiveSwift

/// Describes a Resource which can be fetched from outside of memory,
/// e.g. from an API or on-disk cache.
public enum Resource<Value, Query: Cacheable, Failure: Equatable> {
    public typealias ValueType = Value
    public typealias QueryType = Query
    public typealias FailureType = Failure
}

public extension Resource {
    static func states(
        with loadImpulseEmitter: LoadImpulseEmitter,
        load: @escaping (LoadImpulse) -> SignalProducer<State, Never>
    ) -> Resource.StateProducerType {
        loadImpulseEmitter
            .loadImpulses
            .flatMap(.latest, load)
            .prefix(value: Resource.State.notReady)
    }
}

/// A helper to be used as `Resource.Query` if the Resource has no
/// relevant Query parameters (e.g. for an API call without any
/// changing parameters).
public struct NoQuery: Cacheable {
    public func isCacheCompatible(to other: NoQuery) -> Bool {
        true
    }

    public init() {}
}
