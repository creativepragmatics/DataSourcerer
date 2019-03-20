import DataSourcerer
import Foundation

class PublicReposViewModel {
    typealias Value = PublicReposResponse
    typealias P = VoidParameters
    typealias E = APIError

    lazy var loadImpulseEmitter: RecurringLoadImpulseEmitter<P> = {
        let initialImpulse = LoadImpulse(parameters: P())
        return RecurringLoadImpulseEmitter(initialImpulse: initialImpulse)
    }()

    lazy var datasource: Datasource<Value, P, E> = {

            return Datasource(
                urlRequest: { _ -> URLRequest in
                    let publicReposUrlString: String = "https://api.github.com/repositories"
                    guard let url = URL(string: publicReposUrlString) else {
                        throw NSError(domain: "publicReposUrlString is no URL", code: 100, userInfo: nil)
                    }

                    return URLRequest(url: url)
                },
                mapErrorString: { APIError.unknown(.message($0)) },
                cacheBehavior: .persist(
                    persister: CachePersister<Value, P, E>(key: "public_repos").any,
                    cacheLoadError: E.cacheCouldNotLoad(.default)
                ),
                loadImpulseBehavior: .instance(loadImpulseEmitter.any)
            )
    }()

    func refresh() {
        let loadImpulse = LoadImpulse(parameters: VoidParameters())
        DispatchQueue(label: "PublicReposViewModel.refresh").async { [weak self] in
            self?.loadImpulseEmitter.emit(loadImpulse)
        }
    }

}
