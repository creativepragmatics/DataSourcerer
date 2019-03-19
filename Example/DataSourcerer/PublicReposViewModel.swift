import DataSourcerer
import Foundation

class PublicReposViewModel {
    typealias Value = PublicReposResponseContainer
    typealias P = VoidParameters
    typealias E = APIError

    lazy var loadImpulseEmitter: RecurringLoadImpulseEmitter<P> = {
        let initialImpulse = LoadImpulse(parameters: P())
        return RecurringLoadImpulseEmitter(initialImpulse: initialImpulse)
    }()

    lazy var listDatasource: Datasource
        <Value, P, E, PublicRepoCell, NoSection> = {

            return Datasource(
                urlRequest: { _ -> URLRequest in
                    let publicReposUrlString: String = "https://api.github.com/repositories"
                    guard let url = URL(string: publicReposUrlString) else {
                        throw NSError(domain: "publicReposUrlString is no URL", code: 100, userInfo: nil)
                    }

                    return URLRequest(url: url)
                },
                mapErrorString: { APIError.unknown(.message($0)) },
                cacheBehavior: Datasource.CacheBehavior.persist(
                    persister: CachePersister<Value, P, E>(key: "public_repos").any,
                    cacheLoadError: E.cacheCouldNotLoad(.default)
                ),
                listItemGeneration: Datasource.ListItemGeneration<Value, P, E, PublicRepoCell, NoSection>
                    .singleSection(
                    makeCells: { repos -> [PublicRepoCell] in
                        return repos.map { PublicRepoCell.repo($0) }
                    }
                ),
                loadImpulseBehavior: Datasource.LoadImpulseBehavior.instance(loadImpulseEmitter.any)
            )
    }()

    func refresh() {
        let loadImpulse = LoadImpulse(parameters: VoidParameters())
        DispatchQueue(label: "PublicReposViewModel.refresh").async { [weak self] in
            self?.loadImpulseEmitter.emit(loadImpulse)
        }
    }

}
