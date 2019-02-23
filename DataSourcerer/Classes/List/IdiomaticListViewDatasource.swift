import Foundation

//public struct IdiomaticListViewDatasource
//<Value, P: Parameters, E: StateError, ItemViewProducer: ListItemViewProducer, Section_: ListSection> {
//
//    public typealias Item = ItemViewProducer.Item
//    public typealias Section = Section_
//    public typealias Sections = ListSections<Item, Section>
//    public typealias ItemToView = (Item.ViewType) -> ItemViewProducer
//    public typealias ValueToSections =
//        (Value) -> [SectionWithItems<Item, Section>]?
//    public typealias ItemSelected = (Item, Section) -> Void
//    public typealias StateToSectionsIncomplete =
//        (_ state: State<Value, P, E>,
//        _ valueToSections: @escaping ValueToSections,
//        _ loadingSection: ((State<Value, P, E>) -> SectionWithItems<Item, Section>)?,
//        _ errorSection: ((E) -> SectionWithItems<Item, Section>)?,
//        _ noResultsSection: ((State<Value, P, E>) -> SectionWithItems<Item, Section>)?)
//        -> ListSections<Item, Section>
//
//    public var stateToSectionsIncomplete: StateToSectionsIncomplete
//    public var valueToSections: ValueToSections?
//    public var itemSelected: ItemSelected?
//    public var itemToViewMapping: [Item.ViewType: ItemViewProducer] = [:]
//
//    public var loadingSection: ((State<Value, P, E>) -> Sections.SectionWithItemsConcrete)?
//    public var errorSection: ((E) -> Sections.SectionWithItemsConcrete)?
//    public var noResultsSection: ((State<Value, P, E>) -> Sections.SectionWithItemsConcrete)?
//
//    init(stateToSections: @escaping StateToSectionsIncomplete =
//        IdiomaticListViewDatasource.defaultStateToSections) {
//        self.stateToSectionsIncomplete = stateToSections
//    }
//
//    public static func defaultStateToSections(
//        state: State<Value, P, E>,
//        valueToSections: @escaping ValueToSections,
//        loadingSection: ((State<Value, P, E>) -> SectionWithItems<Item, Section>)?,
//        errorSection: ((E) -> SectionWithItems<Item, Section>)?,
//        noResultsSection: ((State<Value, P, E>) -> SectionWithItems<Item, Section>)?)
//        -> ListSections<Item, Section> {
//
//            return state.listItems(valueToSections: valueToSections,
//                                   loadingSection: loadingSection,
//                                   errorSection: errorSection,
//                                   noResultsSection: noResultsSection)
//    }
//
//    public var builder: Builder {
//        return Builder(configuration: self)
//    }
//
//    func stateToSections(_ state: State<Value, P, E>, valueToSections: ValueToSections? = nil)
//        -> ListSections<Item, Section> {
//            let valueToSections = (valueToSections ?? self.valueToSections) ??
// { _ -> [SectionWithItems<Item, Section>] in
//                let error = Item.E(
//                    message: .message("Set IdiomaticListViewDatasource.valueToSections")
//                )
//                return [SectionWithItems(Section(), [Item(error: error)])]
//            }
//            return stateToSectionsIncomplete(state,
//                                             valueToSections,
//                                             loadingSection,
//                                             errorSection,
//                                             noResultsSection)
//    }
//
//    public static func defaultValueToSections() -> [SectionWithItems<Item, Section>] {
//        let error = Item.E(
//            message: .message("Set IdiomaticListViewDatasource.valueToSections")
//        )
//        return [SectionWithItems(Section(), [Item(error: error)])]
//    }
//
//}
//
//public extension IdiomaticListViewDatasource {
//
//    /// Configures standard components and assumes standard behavior that might be suitable
//    /// for most "normal" list view use cases:
//    ///   - A response container (=value) is shown from which Items are retrieved
//    ///       (configurable via closure)
//    ///   - Pull to refresh is enabled (should become configurable later on)
//    ///   - When loading, a loading cell is shown
//    ///   - If an error occurs, an error item is shown
//    ///   - If no results are visible, a "no results" item is shown
//    ///   - Items can be selectable
//    ///   - TableView updates are animated
//    final class Builder {
//        public typealias Configuration = ListViewDatasource
//
//        public var configuration: Configuration
//
//        init(configuration: Configuration = Configuration()) {
//            self.configuration = configuration
//        }
//
//        /// Has a reasonable default value, so need not be configured.
//        @discardableResult
//        public func stateToSections(_ closure: @escaping Configuration.StateToSectionsIncomplete)
// -> Builder {
//            configuration.stateToSectionsIncomplete = closure
//            return self
//        }
//
//        /// Must be configured to generate actual items.
//        @discardableResult
//        public func valueToSections(_ closure: @escaping Configuration.ValueToSections) -> Builder {
//            configuration.valueToSections = closure
//            return self
//        }
//
//        /// Must be configured to show items in the view.
//        @discardableResult
//        public func itemToView(_ closure: @escaping Configuration.ItemToView) -> Builder {
//            var itemTypeToViewMapping = [Item.ViewType: ItemViewProducer]()
//            Item.ViewType.allCases.forEach { viewType in
//                itemTypeToViewMapping[viewType] = closure(viewType)
//            }
//            configuration.itemToViewMapping = itemTypeToViewMapping
//            return self
//        }
//
//        /// Is called when an Item is selected (Item.ViewType.isSelectable must be true)
//        @discardableResult
//        public func itemSelected(_ closure: @escaping ItemSelected) -> Builder {
//            configuration.itemSelected = closure
//            return self
//        }
//
//        @discardableResult
//        public func loadingSection(_ closure: @escaping (State<Value, P, E>)
//            -> SectionWithItems<Item, Section>)
//            -> Builder {
//                configuration.loadingSection = closure
//                return self
//        }
//
//        @discardableResult
//        public func errorSection(_ closure: @escaping (E) -> SectionWithItems<Item, Section>)
//            -> Builder {
//                configuration.errorSection = closure
//                return self
//        }
//
//        @discardableResult
//        public func noResultsSection(_ closure: @escaping (State<Value, P, E>)
//            -> SectionWithItems<Item, Section>)
//            -> Builder {
//                configuration.noResultsSection = closure
//                return self
//        }
//
//    }
//
//}
