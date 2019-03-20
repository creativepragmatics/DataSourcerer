import Foundation

public struct ListItemProducer
<Value, P: Parameters, E, Item: ListItem, Section: ListSection> where Item.E == E {

    public typealias StateToListViewState =
        (State<Value, P, E>, ValueToListViewStateTransformer<Value, Item, Section>)
        -> ListViewState<Item, Section>

    private let stateToListViewState: StateToListViewState
    private let valueToListViewStateTransformer: ValueToListViewStateTransformer<Value, Item, Section>

    public init(stateToListViewState: @escaping StateToListViewState,
                valueToListViewStateTransformer: ValueToListViewStateTransformer<Value, Item, Section>) {

        self.stateToListViewState = stateToListViewState
        self.valueToListViewStateTransformer = valueToListViewStateTransformer
    }

    public init(baseValueToListViewStateTransformer: ValueToListViewStateTransformer<Value, Item, Section>) {

        self.stateToListViewState = { state, valueToListViewStateTransformer in
            if let value = state.value?.value {
                return valueToListViewStateTransformer.valueToListViewState(value)
            } else {
                return .notReady
            }
        }
        self.valueToListViewStateTransformer = baseValueToListViewStateTransformer
    }

    public static func withSingleSectionItems<P: Parameters>(
        _ singleSectionItems: @escaping (Value) -> [Item]
        ) -> ListItemProducer<Value, P, E, Item, NoSection> where Item.E == E {

        let valueToListViewStateTransformer =
            ValueToListViewStateTransformer<Value, Item, NoSection> { value in
                let section = SectionWithItems<Item, NoSection>(NoSection(), singleSectionItems(value))
                return ListViewState<Item, NoSection>.readyToDisplay([section])
            }

        return ListItemProducer<Value, P, E, Item, NoSection>(
            baseValueToListViewStateTransformer: valueToListViewStateTransformer
        )
    }

    public func listViewState(with state: State<Value, P, E>) -> ListViewState<Item, Section> {
        return stateToListViewState(state, valueToListViewStateTransformer)
    }

    public func idiomatic(noResultsText: String)
        -> ListItemProducer<Value, P, E, IdiomaticListItem<Item>, Section> {

            return ListItemProducer<Value, P, E, IdiomaticListItem<Item>, Section>(
                stateToListViewState: { state, valueToIdiomaticListViewStateTransformer
                    -> ListViewState<IdiomaticListItem<Item>, Section> in

                    return state.idiomaticListViewState(
                        valueToIdiomaticListViewStateTransformer: valueToIdiomaticListViewStateTransformer,
                        noResultsText: noResultsText
                    )
                },
                valueToListViewStateTransformer: valueToListViewStateTransformer.idiomatic()
            )
    }

}

public struct ValueToListViewStateTransformer
<Value, Item: ListItem, Section: ListSection> {

    public typealias ValueToListViewState = (Value) -> ListViewState<Item, Section>

    public let valueToListViewState: ValueToListViewState

    public init(_ valueToListViewState: @escaping ValueToListViewState) {
        self.valueToListViewState = valueToListViewState
    }

    public func idiomatic()
        -> ValueToListViewStateTransformer<Value, IdiomaticListItem<Item>, Section> {

            return ValueToListViewStateTransformer<Value, IdiomaticListItem<Item>, Section> { value
                -> ListViewState<IdiomaticListItem<Item>, Section> in

                let innerListViewState = self.valueToListViewState(value)
                switch innerListViewState {
                case let .readyToDisplay(sectionsWithItems):
                    return .readyToDisplay(sectionsWithItems.map { sectionWithItems in
                        return SectionWithItems(sectionWithItems.section,
                                                sectionWithItems.items.map { IdiomaticListItem.baseItem($0) })
                    })
                case .notReady:
                    return .notReady
                }
            }
    }
}
