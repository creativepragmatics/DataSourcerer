import Foundation

public extension ObservableProtocol {

    typealias LoadingEnded = Void

    /// Returns AnyObservable because it does not necessarily,
    /// like Datasources, send an initial value synchronously
    /// when observe(_) is called.
    func loadingEnded<Value, P: ResourceParams, E: ResourceError>()
        -> AnyObservable<LoadingEnded> where ObservedValue == ResourceState<Value, P, E> {

            return self
                .filter { state in
                    switch state.provisioningState {
                    case .result:
                        return true
                    case .notReady, .loading:
                        return false
                    }
                }
                .map { _ in LoadingEnded() }
    }

}
