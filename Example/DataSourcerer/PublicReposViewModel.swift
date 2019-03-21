import DataSourcerer
import Foundation

class PublicReposViewModel {

    lazy var loadImpulseEmitter: RecurringLoadImpulseEmitter<NoResourceParams> = {
        let initialImpulse = LoadImpulse(params: NoResourceParams())
        return RecurringLoadImpulseEmitter(initialImpulse: initialImpulse)
    }()

    lazy var datasource: Datasource = {

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
                    persister: CachePersister(key: "public_repos").any,
                    cacheLoadError: APIError.cacheCouldNotLoad(.default)
                )
            )
            .datasource
    }()

}
