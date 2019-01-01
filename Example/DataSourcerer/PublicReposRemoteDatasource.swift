import DataSourcerer
import Foundation

struct PublicReposPrimaryDatasourceBuilder {
    typealias Value = PublicReposResponseContainer
    typealias P = VoidParameters
    typealias E = APIError
    typealias Datasource = URLSessionDatasource<PublicReposResponseContainer, VoidParameters, APIError>

    let loadImpulseEmitter: AnyLoadImpulseEmitter<P>
    let loadsSynchronously: Bool = false

    init(loadImpulseEmitter: AnyLoadImpulseEmitter<P>) {
        self.loadImpulseEmitter = loadImpulseEmitter
    }

    var datasource: Datasource {
        return URLSessionDatasource(
            loadImpulseEmitter: loadImpulseEmitter,
            generateError: { APIError.unknown(description: $0) },
            generateRequest: { _ throws -> URLRequest in
                let publicReposUrlString: String = "https://api.github.com/repositories"
                guard let url = URL(string: publicReposUrlString) else {
                    throw NSError(domain: "publicReposUrlString is no URL", code: 100, userInfo: nil)
                }

                return URLRequest(url: url)
            }
        )
    }

}

struct VoidParameters: Parameters, Codable {
    func isCacheCompatible(_ candidate: VoidParameters) -> Bool {
        return true
    }
}
