import DataSourcerer
import Foundation

struct PublicReposPrimaryDatasourceBuilder {
    typealias Value = PublicReposResponse
    typealias P = NoResourceParams
    typealias E = APIError

    func datasource(with loadImpulseEmitter: AnyLoadImpulseEmitter<P>)
        -> ValueStream<ResourceState<Value, P, E>> {

        return ValueStream(
            loadStatesWithURLRequest: { _ -> URLRequest in
                let publicReposUrlString: String = "https://api.github.com/repositories"
                guard let url = URL(string: publicReposUrlString) else {
                    throw NSError(domain: "publicReposUrlString is no URL", code: 100, userInfo: nil)
                }

                return URLRequest(url: url)
            },
            mapErrorString: { APIError.unknown(.message($0)) },
            loadImpulseEmitter: loadImpulseEmitter
        )
    }

}

struct NoResourceParams: ResourceParams, Codable {
    func isCacheCompatible(_ candidate: NoResourceParams) -> Bool {
        return true
    }
}
