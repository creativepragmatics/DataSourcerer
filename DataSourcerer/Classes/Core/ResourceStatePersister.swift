import Foundation

public protocol ResourceStatePersister {
    associatedtype Value: Any
    associatedtype P: ResourceParams
    associatedtype E: ResourceError
    typealias PersistedState = ResourceState<Value, P, E>

    func persist(_ state: PersistedState)
    func load(_ parameters: P) -> PersistedState?
    func purge()
}

public extension ResourceStatePersister {
    var any: AnyResourceStatePersister<Value, P, E> {
        return AnyResourceStatePersister(self)
    }
}

public struct AnyResourceStatePersister<Value_: Any, P_: ResourceParams, E_: ResourceError>
: ResourceStatePersister {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_

    private let _persist: (PersistedState) -> Void
    private let _load: (P) -> PersistedState?
    private let _purge: () -> Void

    public init<SP: ResourceStatePersister>(_ persister: SP) where SP.PersistedState == PersistedState {
        self._persist = persister.persist
        self._load = persister.load
        self._purge = persister.purge
    }

    public func persist(_ state: PersistedState) {
        _persist(state)
    }

    public func load(_ parameters: P) -> PersistedState? {
        return _load(parameters)
    }

    public func purge() {
        _purge()
    }
}
