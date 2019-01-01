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

    private lazy var primaryDatasource: AnyDatasource<State<Value, P, E>> = {
        return PublicReposPrimaryDatasourceBuilder(loadImpulseEmitter: loadImpulseEmitter.any)
            .datasource
            .any
    }()

    lazy var datasource: CachedDatasource<Value, P, E> = {
        let persister = CachePersister<Value, P, E>(key: "public_repos").any
        let primaryDatasource =
            PublicReposPrimaryDatasourceBuilder(loadImpulseEmitter: loadImpulseEmitter.any)
                .datasource
                .any
        let cacheDatasource = PlainCacheDatasource<Value, P, E>(
            persister: persister.any,
            loadImpulseEmitter: loadImpulseEmitter.any,
            cacheLoadError: APIError.cacheCouldNotLoad(.default)
        ).any
        return self.primaryDatasource
            .retainLastResult()
            .cache(with: cacheDatasource,
                   loadImpulseEmitter: loadImpulseEmitter.any,
                   persister: persister)
    }()

    func refresh() {
        let loadImpulse = LoadImpulse(parameters: VoidParameters())
        loadImpulseEmitter.emit(loadImpulse)
    }

}
