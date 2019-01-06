import Foundation
import DataSourcerer

public class TestStatePersister<Value_: Codable, P_: Parameters & Codable, E_: StateError & Codable>: StatePersister {
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
            state.loadImpulse?.parameters.isCacheCompatible(parameters) ?? false else {
            return nil
        }

        return state
    }

    public func purge() {
        state = nil
    }

}
