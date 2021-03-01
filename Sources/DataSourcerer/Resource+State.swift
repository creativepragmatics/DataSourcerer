import Foundation
import ReactiveSwift

public extension Resource {
    typealias StateProducerType = SignalProducer<State, Never>

    /// Describes what state a resource (either loaded from an API,
    /// from memory, disk, computed on the fly,...) is in.
    struct State: Equatable {
        public var provisioningState: ProvisioningState
        public var loadImpulse: Resource.LoadImpulse?
        public var value: EquatableBox<Value>?
        public var error: Failure?

        public init(
            provisioningState: ProvisioningState,
            loadImpulse: Resource.LoadImpulse?,
            value: EquatableBox<Value>?,
            error: Failure?
        ) {
            self.provisioningState = provisioningState
            self.loadImpulse = loadImpulse
            self.value = value
            self.error = error
        }
    }
}

public extension Resource.State {
    func with(value: EquatableBox<Value>?) -> Self {
        .init(
            provisioningState: provisioningState,
            loadImpulse: loadImpulse,
            value: value,
            error: error
        )
    }

    func with(error: Failure?) -> Self {
        .init(
            provisioningState: provisioningState,
            loadImpulse: loadImpulse,
            value: value,
            error: error
        )
    }
}

public extension Resource.State {
    func map<Transformed>(_ transform: (Value) -> Transformed)
    -> Resource<Transformed, Query, Failure>.State  {
        .init(
            provisioningState: provisioningState,
            loadImpulse: loadImpulse.map {
                Resource<Transformed, Query, Failure>.LoadImpulse(
                    query: $0.query,
                    type: $0.type,
                    id: $0.id
               )
            },
            value: value?.map(transform),
            error: error
        )
    }
}

extension Resource.State: Codable where Value: Codable, Query: Codable, Failure: Codable {}

public extension Resource.State {

    /// Datasource is not ready to provide data.
    static var notReady: Resource.State {
        return Resource.State(provisioningState: .notReady, loadImpulse: nil, value: nil, error: nil)
    }

    /// An error has been encountered in a datasource (e.g. while loading).
    /// A value can still be defined (e.g. API call failed, but a cache value is
    /// available).
    static func error(
        error: Failure,
        loadImpulse: Resource.LoadImpulse,
        fallbackValueBox: EquatableBox<Value>?
    ) -> Resource.State {
        return Resource.State(
            provisioningState: .result,
            loadImpulse: loadImpulse,
            value: fallbackValueBox,
            error: error
        )
    }

    /// A value has been created in a datasource. An error can still be defined
    /// (e.g. a cached value has been found, but )
    static func value(
        valueBox: EquatableBox<Value>,
        loadImpulse: Resource.LoadImpulse,
        fallbackError: Failure?
    ) -> Resource.State {
        return Resource.State(
            provisioningState: .result,
            loadImpulse: loadImpulse,
            value: valueBox,
            error: fallbackError
        )
    }

    /// The emitting datasource is loading, and has a fallbackValue (e.g. from a cache), or
    /// a fallback error, or both.
    static func loading(
        loadImpulse: Resource.LoadImpulse,
        fallbackValueBox: EquatableBox<Value>?,
        fallbackError: Failure?
    ) -> Resource.State {
        return Resource.State(
            provisioningState: .loading,
            loadImpulse: loadImpulse,
            value: fallbackValueBox,
            error: fallbackError
        )
    }

    func hasLoadedSuccessfully(for loadImpulse: Resource.LoadImpulse) -> Bool {
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

    func cacheCompatibleValue(
        for loadImpulse: Resource.LoadImpulse
    ) -> EquatableBox<Value>? {
        guard let value = self.value,
            let selfLoadImpulse = self.loadImpulse,
            selfLoadImpulse.isCacheCompatible(loadImpulse) else {
                return nil
        }
        return value
    }

    func cacheCompatibleError(
        for loadImpulse: Resource.LoadImpulse
    ) -> Failure? {
        guard let error = self.error,
            let selfLoadImpulse = self.loadImpulse,
            selfLoadImpulse.isCacheCompatible(loadImpulse) else {
                return nil
        }
        return error
    }

}
