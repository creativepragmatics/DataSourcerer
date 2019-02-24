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
        return PublicReposPrimaryDatasourceBuilder()
            .datasource(with: loadImpulseEmitter.any)
            .retainLastResultState()
            .persistedCachedState(persister: CachePersister<Value, P, E>(key: "public_repos").any,
                                  loadImpulseEmitter: loadImpulseEmitter.any,
                                  cacheLoadError: APIError.cacheCouldNotLoad(.default))
            .skipRepeats()
            .property(initialValue: .notReady)
    }()

    lazy var listDatasource: ListDatasource
        <State<Value, P, E>, PublicRepoCell, NoSection> = {

        let valueAndSections = states
            .map { state
                -> ListValueAndSections<State<Value, P, E>, PublicRepoCell, NoSection> in

                let cells = state.value?.value.map { PublicRepoCell.repo($0) } ?? []
                let sections = ListSections<PublicRepoCell, NoSection>.readyToDisplay(
                    [
                        SectionWithItems<PublicRepoCell, NoSection>(NoSection(), cells)
                    ]
                )
                return ListValueAndSections(value: state, sections: sections)
            }
            .property(initialValue: ListValueAndSections(value: states.value, sections: .notReady))
        return ListDatasource(valueAndSections)
    }()

    func refresh() {
        let loadImpulse = LoadImpulse(parameters: VoidParameters())
        DispatchQueue(label: "PublicReposViewModel.refresh").async { [weak self] in
            self?.loadImpulseEmitter.emit(loadImpulse)
        }
    }

}
