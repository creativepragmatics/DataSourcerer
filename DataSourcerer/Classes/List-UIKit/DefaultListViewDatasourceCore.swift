import Foundation
import UIKit

public struct DefaultListViewDatasourceCore
<Datasource: StateDatasourceProtocol, ItemViewProducer: ListItemViewProducer, Section_: ListSection> {

    public typealias Item = ItemViewProducer.Item
    public typealias Section = Section_
    public typealias Sections = ListSections<Item, Section>
    public typealias ItemToView = (Item.ViewType) -> ItemViewProducer
    public typealias ValueToSections =
        (Datasource.DatasourceState.Value) -> [SectionWithItems<Item, Section>]?
    public typealias ItemSelected = (Item, Section) -> Void
    public typealias StateToSectionsIncomplete =
        (_ state: Datasource.DatasourceState,
        _ valueToSections: @escaping ValueToSections,
        _ loadingSection: ((Datasource.DatasourceState) -> SectionWithItems<Item, Section>)?,
        _ errorSection: ((Datasource.E) -> SectionWithItems<Item, Section>)?,
        _ noResultsSection: ((Datasource.DatasourceState) -> SectionWithItems<Item, Section>)?)
        -> ListSections<Item, Section>

    public var stateToSectionsIncomplete: StateToSectionsIncomplete
    public var valueToSections: ValueToSections?
    public var itemSelected: ItemSelected?
    public var itemToViewMapping: [Item.ViewType: ItemViewProducer] = [:]

    public var loadingSection: ((Datasource.DatasourceState) -> Sections.SectionWithItemsConcrete)?
    public var errorSection: ((Datasource.E) -> Sections.SectionWithItemsConcrete)?
    public var noResultsSection: ((Datasource.DatasourceState) -> Sections.SectionWithItemsConcrete)?

    init(stateToSections: @escaping StateToSectionsIncomplete =
        DefaultListViewDatasourceCore.defaultStateToSections) {
        self.stateToSectionsIncomplete = stateToSections
    }

    public static func defaultStateToSections(
        state: Datasource.DatasourceState,
        valueToSections: @escaping ValueToSections,
        loadingSection: ((Datasource.DatasourceState) -> SectionWithItems<Item, Section>)?,
        errorSection: ((Datasource.E) -> SectionWithItems<Item, Section>)?,
        noResultsSection: ((Datasource.DatasourceState) -> SectionWithItems<Item, Section>)?)
        -> ListSections<Item, Section> {

        return state.listItems(valueToSections: valueToSections,
                               loadingSection: loadingSection,
                               errorSection: errorSection,
                               noResultsSection: noResultsSection)
    }

    public var builder: Builder {
        return Builder(core: self)
    }

    func stateToSections(_ state: Datasource.DatasourceState) -> ListSections<Item, Section> {
        let valueToSections = self.valueToSections ?? { _ -> [SectionWithItems<Item, Section>] in
            let errorItem = Item(errorMessage: "Set DefaultListViewDatasourceCore.valueToSections")
            return [SectionWithItems(Section(), [errorItem])]
        }
        return stateToSectionsIncomplete(state,
                                         valueToSections,
                                         loadingSection,
                                         errorSection,
                                         noResultsSection)
    }

}

public extension DefaultListViewDatasourceCore {

    /// Configures standard components and assumes standard behavior that might be suitable
    /// for most "normal" UITableView use cases:
    ///   - Cached datasource is required (which can also be instantiated without a cache BTW)
    ///   - A response container is shown from which Items are retrieved (configurable via closure)
    ///   - Pull to refresh is enabled (might be configurable later on)
    ///   - When loading, a UIActivityIndicatorView is shown in a item
    ///   - If an error occurs, a specific item is shown
    ///   - If no results are visible, a specific item is shown
    ///   - Items are either selectable or not
    ///   - TableView updates are animated if the view is visible
    ///
    /// Usage: Instantiate and configure with the offered parameters and functions and add the
    /// `tableViewController` to the view hierarchy.
    struct Builder {
        public typealias Core = DefaultListViewDatasourceCore

        public var core: Core

        init(core: Core = Core()) {
            self.core = core
        }

        /// Has a reasonable default value, so need not be configured.
        @discardableResult
        public func stateToSections(_ closure: @escaping Core.StateToSectionsIncomplete) -> Builder {
            var core = self.core
            core.stateToSectionsIncomplete = closure
            return core.builder
        }

        /// Must be configured to generate actual items.
        @discardableResult
        public func valueToSections(_ closure: @escaping Core.ValueToSections) -> Builder {
            var core = self.core
            core.valueToSections = closure
            return core.builder
        }

        /// Must be configured to show items in the view.
        @discardableResult
        public func itemToView(_ closure: @escaping Core.ItemToView) -> Builder {
            var core = self.core
            var itemTypeToViewMapping = [Item.ViewType: ItemViewProducer]()
            Item.ViewType.allCases.forEach { viewType in
                itemTypeToViewMapping[viewType] = closure(viewType)
            }
            core.itemToViewMapping = itemTypeToViewMapping
            return core.builder
        }

        /// Is called when an Item is selected (Item.ViewType.isSelectable must be true)
        @discardableResult
        public func itemSelected(_ closure: @escaping ItemSelected) -> Builder {
            var core = self.core
            core.itemSelected = closure
            return core.builder
        }

        @discardableResult
        public func loadingSection(_ closure: @escaping (Datasource.DatasourceState)
            -> SectionWithItems<Item, Section>)
            -> Builder {
            var core = self.core
            core.loadingSection = closure
            return core.builder
        }

        @discardableResult
        public func errorSection(_ closure: @escaping (Datasource.E) -> SectionWithItems<Item, Section>)
            -> Builder {
            var core = self.core
            core.errorSection = closure
            return core.builder
        }

        @discardableResult
        public func noResultsSection(_ closure: @escaping (Datasource.DatasourceState)
            -> SectionWithItems<Item, Section>)
            -> Builder {
            var core = self.core
            core.noResultsSection = closure
            return core.builder
        }

    }

}
