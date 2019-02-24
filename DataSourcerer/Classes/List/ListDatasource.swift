import Foundation

public struct ListDatasource<ObservedValue, Item: ListItem, Section: ListSection> {
    public typealias ValueAndSections = ListValueAndSections<ObservedValue, Item, Section>

    public let valueAndSections: ObservableProperty<ValueAndSections>

    public init(_ valueAndSections: ObservableProperty<ValueAndSections>) {
        self.valueAndSections = valueAndSections
    }
}

public extension ListDatasource {

    typealias IdiomaticItem = IdiomaticListItem<Item>
    typealias IdiomaticValueAndSections
        = ListValueAndSections<ObservedValue, IdiomaticItem, Section>

    func idiomatic<Value, P: Parameters, E: StateError>()
        -> ListDatasource<ObservedValue, IdiomaticListItem<Item>, Section>
        where ObservedValue == State<Value, P, E> {

        typealias IdiomaticItem = IdiomaticListItem<Item>
        typealias IdiomaticSections = ListSections<IdiomaticItem, Section>

        func idiomaticValueAndSections(_ valueAndSections: ValueAndSections)
            -> IdiomaticValueAndSections {
                let idiomaticSections = valueAndSections.sections.sectionsWithItems?
                    .map { sectionWithItems -> SectionWithItems<IdiomaticItem, Section> in
                        let items = sectionWithItems.items
                            .map { IdiomaticListItem.datasourceItem($0) }
                        return SectionWithItems(sectionWithItems.section, items)
                    }

                return ListValueAndSections(
                    value: valueAndSections.value,
                    sections: IdiomaticSections.readyToDisplay(idiomaticSections ?? [])
                )
        }

        let idiomaticValueAndSectionsProperty = valueAndSections
            .map { idiomaticValueAndSections($0) }
            .property(
                initialValue: idiomaticValueAndSections(self.valueAndSections.value)
        )

        return ListDatasource<ObservedValue, IdiomaticListItem<Item>, Section>(
            idiomaticValueAndSectionsProperty
        )
    }
}
