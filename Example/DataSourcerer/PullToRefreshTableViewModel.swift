import DataSourcerer
import Foundation

class PullToRefreshTableViewModel {

    lazy var loadImpulseEmitter: RecurringLoadImpulseEmitter<NoResourceParams> = {
        let initialImpulse = LoadImpulse(params: NoResourceParams(), type: .initial)
        return RecurringLoadImpulseEmitter(initialImpulse: initialImpulse)
    }()

    lazy var datasource: Datasource = {

        return Datasource
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
            .setRememberLatestSuccessAndErrorBehavior(
                RememberLatestSuccessAndErrorBehavior(
                    preferFallbackValueOverFallbackError: true
                )
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
