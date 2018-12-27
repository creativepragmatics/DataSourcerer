import Foundation

public protocol StatePersister {
    associatedtype Value: Any
    associatedtype P: Parameters
    associatedtype E: DatasourceError
    typealias PersistedState = State<Value, P, E>

    func persist(_ state: PersistedState)
    func load(_ parameters: P) -> PersistedState?
    func purge()
}

public extension StatePersister {
    var any: AnyStatePersister<Value, P, E> {
        return AnyStatePersister(self)
    }
}

public struct AnyStatePersister<Value_: Any, P_: Parameters, E_: DatasourceError> : StatePersister {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_

    private let _persist: (PersistedState) -> Void
    private let _load: (P) -> PersistedState?
    private let _purge: () -> Void

    public init<SP: StatePersister>(_ persister: SP) where SP.PersistedState == PersistedState {
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
