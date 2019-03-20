import DataSourcerer
import Foundation

class PublicReposViewModel {
    typealias Value = PublicReposResponse
    typealias P = NoResourceParams
    typealias E = APIError

    lazy var loadImpulseEmitter: RecurringLoadImpulseEmitter<P> = {
        let initialImpulse = LoadImpulse(parameters: P())
        return RecurringLoadImpulseEmitter(initialImpulse: initialImpulse)
    }()

    lazy var datasource: Datasource<Value, P, E> = {

        return Datasource.Builder
            .loadFromURL(
                urlRequest: { _ -> URLRequest in
                    let publicReposUrlString: String = "https://api.github.com/repositories"
                    guard let url = URL(string: publicReposUrlString) else {
                        throw NSError(domain: "publicReposUrlString is no URL", code: 100, userInfo: nil)
                    }

                    return URLRequest(url: url)
                },
                withParameterType: NoResourceParams.self,
                expectResponseValueType: PublicReposResponse.self,
                failWithError: APIError.self
            )
            .mapErrorToString { APIError.unknown(.message($0)) }
            .loadImpulseBehavior(.instance(loadImpulseEmitter.any))
            .cacheBehavior(
                .persist(
                    persister: CachePersister<Value, P, E>(key: "public_repos").any,
                    cacheLoadError: E.cacheCouldNotLoad(.default)
                )
            )
            .datasource
    }()

    func refresh() {
        let loadImpulse = LoadImpulse(parameters: NoResourceParams())
        DispatchQueue(label: "PublicReposViewModel.refresh").async { [weak self] in
            self?.loadImpulseEmitter.emit(loadImpulse)
        }
    }

}
