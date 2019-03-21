import Foundation
import DataSourcerer

public class TestResourceStatePersister<Value_: Codable, P_: ResourceParams & Codable, E_: ResourceError & Codable>: ResourceStatePersister {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_

    public typealias StatePersistenceKey = String

    private var state: PersistedState?

    public func persist(_ state: PersistedState) {
        self.state = state
    }

    public func load(_ parameters: P) -> PersistedState? {
        guard let state = self.state,
            state.loadImpulse?.params.isCacheCompatible(parameters) ?? false else {
            return nil
        }

        return state
    }

    public func purge() {
        state = nil
    }

}
