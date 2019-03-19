import Foundation

/// Provides the data for a sectioned or unsectioned list. Can be reused
/// by multiple views displaying its data.
public struct Datasource
<Value, P: Parameters, E: StateError, Item: ListItem, Section: ListSection> {
    public typealias ObservedState = State<Value, P, E>
    public typealias StateAndSections = ListStateAndSections<ObservedState, Item, Section>

    public let stateAndSections: ShareableValueStream<StateAndSections>
    public let loadImpulseEmitter: AnyLoadImpulseEmitter<P>

    public init(_ stateAndSections: ShareableValueStream<StateAndSections>,
                loadImpulseEmitter: AnyLoadImpulseEmitter<P>) {
        self.stateAndSections = stateAndSections
        self.loadImpulseEmitter = loadImpulseEmitter
    }
}

public extension Datasource {

    enum CacheBehavior<Value, P: Parameters, E: StateError> {
        case none
        case persist(persister: AnyStatePersister<Value, P, E>, cacheLoadError: E)

        func apply(on observable: AnyObservable<State<Value, P, E>>,
                   loadImpulseEmitter: AnyLoadImpulseEmitter<P>)
            -> AnyObservable<State<Value, P, E>> {
                switch self {
                case .none:
                    return observable
                case let .persist(persister, cacheLoadError):
                    return observable.persistedCachedState(
                        persister: persister,
                        loadImpulseEmitter: loadImpulseEmitter,
                        cacheLoadError: cacheLoadError
                    )
                }
        }
    }
}

public extension Datasource {

    enum LoadImpulseBehavior<P: Parameters> {
        case `default`(initialParameters: P?)
        case recurring(
            initialParameters: P?,
            timerMode: RecurringLoadImpulseEmitter<P>.TimerMode,
            timerEmitQueue: DispatchQueue?
        )
        case instance(AnyLoadImpulseEmitter<P>)

        var loadImpulseEmitter: AnyLoadImpulseEmitter<P> {
            switch self {
            case let .default(initialParameters):
                let initialImpulse = initialParameters.map { LoadImpulse<P>(parameters: $0) }
                return SimpleLoadImpulseEmitter(initialImpulse: initialImpulse).any
            case let .instance(loadImpulseEmitter):
                return loadImpulseEmitter
            case let .recurring(initialParameters,
                                timerMode,
                                timerEmitQueue):
                let initialImpulse = initialParameters.map { LoadImpulse<P>(parameters: $0) }
                return RecurringLoadImpulseEmitter(initialImpulse: initialImpulse,
                                                   timerMode: timerMode,
                                                   timerEmitQueue: timerEmitQueue).any
            }
        }
    }

}

public extension Datasource {

    enum ListItemGeneration
        <Value, P: Parameters, E: StateError, Item: ListItem, Section: ListSection> {

        case singleSection(makeCells: (Value) -> [Item])

        func listStateAndSections(state: State<Value, P, E>)
            -> ListStateAndSections<State<Value, P, E>, Item, Section> {

                switch self {
                case let .singleSection(makeCells):
                    let cells = (state.value?.value).map { makeCells($0) } ?? []
                    let sections = ListSections<Item, Section>.readyToDisplay(
                        [
                            SectionWithItems<Item, Section>(Section(), cells)
                        ]
                    )
                    return ListStateAndSections(value: state, sections: sections)

                }
        }
    }

}

public extension Datasource where Value: Codable {

    typealias ErrorString = String

    init(
        urlRequest: @escaping (LoadImpulse<P>) throws -> URLRequest,
        mapErrorString: @escaping (ErrorString) -> E,
        cacheBehavior: CacheBehavior<Value, P, E>,
        listItemGeneration: ListItemGeneration<Value, P, E, Item, Section>,
        loadImpulseBehavior: LoadImpulseBehavior<P>
        ) {

        let loadImpulseEmitter = loadImpulseBehavior.loadImpulseEmitter

        let states = ValueStream<ObservedState>(
            loadStatesWithURLRequest: urlRequest,
            mapErrorString: mapErrorString,
            loadImpulseEmitter: loadImpulseEmitter
            )
            .retainLastResultState()

        let cachedStates = cacheBehavior
            .apply(on: states.any,
                   loadImpulseEmitter: loadImpulseEmitter)
            .skipRepeats()

         let listStateAndSections = cachedStates
            .map { listItemGeneration.listStateAndSections(state: $0) }

        let shareableListStateAndSections = listStateAndSections
            .observeOnUIThread()
            .shareable(
                initialValue: ListStateAndSections(value: State<Value, P, E>.notReady, sections: .notReady)
            )

        self.init(shareableListStateAndSections, loadImpulseEmitter: loadImpulseEmitter)
    }
}

public extension Datasource {

    typealias IdiomaticItem = IdiomaticListItem<Item>
    typealias IdiomaticStateAndSections
        = ListStateAndSections<ObservedState, IdiomaticItem, Section>

    func idiomatic() -> Datasource<Value, P, E, IdiomaticListItem<Item>, Section> {

        typealias IdiomaticItem = IdiomaticListItem<Item>
        typealias IdiomaticSections = ListSections<IdiomaticItem, Section>

        func idiomaticStateAndSections(_ stateAndSections: StateAndSections)
            -> IdiomaticStateAndSections {
                let idiomaticSections = stateAndSections.sections.sectionsWithItems?
                    .map { sectionWithItems -> SectionWithItems<IdiomaticItem, Section> in
                        let items = sectionWithItems.items
                            .map { IdiomaticListItem.baseItem($0) }
                        return SectionWithItems(sectionWithItems.section, items)
                    }

                return ListStateAndSections(
                    value: stateAndSections.value,
                    sections: IdiomaticSections.readyToDisplay(idiomaticSections ?? [])
                )
        }

        let shareableIdiomaticStateAndSections = stateAndSections
            .map { idiomaticStateAndSections($0) }
            .shareable(
                initialValue: idiomaticStateAndSections(self.stateAndSections.value)
            )

        return Datasource<Value, P, E, IdiomaticListItem<Item>, Section>(
            shareableIdiomaticStateAndSections,
            loadImpulseEmitter: self.loadImpulseEmitter
        )
    }
}
