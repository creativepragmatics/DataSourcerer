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

    lazy var states: ObservableProperty<State<Value, P, E>> = {
        return PublicReposPrimaryDatasourceBuilder(loadImpulseEmitter: loadImpulseEmitter.any)
            .datasource
            .retainLastResultState()
            .persistedCachedState(persister: CachePersister<Value, P, E>(key: "public_repos").any,
                                  loadImpulseEmitter: loadImpulseEmitter.any,
                                  cacheLoadError: APIError.cacheCouldNotLoad(.default))
            .observeOnUIThread()
            .property(initialValue: .notReady)
    }()

    func refresh() {
        let loadImpulse = LoadImpulse(parameters: VoidParameters())
        DispatchQueue(label: "PublicReposViewModel.refresh").async { [weak self] in
            self?.loadImpulseEmitter.emit(loadImpulse)
        }
    }

}
