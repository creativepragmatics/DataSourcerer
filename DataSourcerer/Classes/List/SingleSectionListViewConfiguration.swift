import Foundation

//public struct SingleSectionListViewConfiguration
//<Value, P: Parameters, E: StateError, ItemViewProducer: ListItemViewProducer> {
//
//    public typealias ObservedState = State<Value, P, E>
//    public typealias Item = ItemViewProducer.Item
//    public typealias Items = SingleSectionListViewState<Item>
//    public typealias ItemToView = (Item.ViewType) -> ItemViewProducer
//    public typealias ValueToItems = (Value) -> [Item]?
//    public typealias ItemSelected = (Item) -> Void
//    public typealias StateToItemsIncomplete =
//        (_ state: ObservedState,
//        _ valueToItems: @escaping ValueToItems,
//        _ loadingItem: ((ObservedState) -> Item)?,
//        _ errorItem: ((E) -> Item)?,
//        _ noResultsItem: ((ObservedState) -> Item)?) -> SingleSectionListViewState<Item>
//
//    public var stateToItemsIncomplete: StateToItemsIncomplete
//    public var valueToItems: ValueToItems?
//    public var itemSelected: ItemSelected?
//    public var itemToViewMapping: [Item.ViewType: ItemViewProducer]
//
//    public var loadingItem: ((ObservedState) -> Item)?
//    public var errorItem: ((E) -> Item)?
//    public var noResultsItem: ((ObservedState) -> Item)?
//
//    /// If true, use heightAtIndexPath to store item heights. Most likely
//    /// only makes sense in TableViews with autolayouted cells.
//    public var useFixedItemHeights = false
//    public var heightAtIndexPath: [IndexPath: CGFloat] = [:]
//
//    public init(stateToItemsIncomplete: @escaping StateToItemsIncomplete =
//        SingleSectionListViewConfiguration.defaultStateToItems) {
//        self.stateToItemsIncomplete = stateToItemsIncomplete
//    }
//
//    public static func defaultStateToItems(state: ObservedState,
//                                           valueToItems: @escaping ValueToItems,
//                                           loadingItem: ((ObservedState) -> Item)?,
//                                           errorItem: ((E) -> Item)?,
//                                           noResultsItem: ((ObservedState) -> Item)?)
//        -> SingleSectionListViewState<Item> {
//
//        return state.singleSectionListItems(valueToItems: valueToItems,
//                                            loadingItem: loadingItem,
//                                            errorItem: errorItem,
//                                            noResultsItem: noResultsItem)
//    }
//
//    public var builder: Builder {
//        return Builder(configuration: self)
//    }
//
//    func stateToItems(_ state: ObservedState) -> Items {
//        let valueToItems = self.valueToItems ?? { _ -> [Item] in
//            let error = Item.E(
//                message: .message("Set IdiomaticSingleSectionListViewDatasourceCore.valueToItems")
//            )
//            return [Item(error: error)]
//        }
//        return stateToItemsIncomplete(state, valueToItems, loadingItem, errorItem, noResultsItem)
//    }
//
//}
//
//public extension SingleSectionListViewConfiguration {
//
//    /// Configures standard components and assumes standard behavior that might be suitable
//    /// for most "normal" UITableView use cases:
//    ///   - Cached datasource is required (which can also be instantiated without a cache BTW)
//    ///   - A response container is shown from which Items are retrieved (configurable via closure)
//    ///   - Pull to refresh is enabled (might be configurable later on)
//    ///   - When loading, a UIActivityIndicatorView is shown in a item
//    ///   - If an error occurs, a specific item is shown
//    ///   - If no results are visible, a specific item is shown
//    ///   - Items are either selectable or not
//    ///   - TableView updates are animated if the view is visible
//    ///
//    /// Usage: Instantiate and configure with the offered parameters and functions and add the
//    /// `tableViewController` to the view hierarchy.
//    final class Builder {
//        public typealias Configuration = SingleSectionListViewConfiguration
//
//        public var configuration: Configuration
//
//        public init(configuration: Configuration = Configuration()) {
//            self.configuration = configuration
//        }
//
//        /// Has a reasonable default value, so need not be configured.
//        @discardableResult
//        public func stateToItems(_ closure: @escaping Configuration.StateToItemsIncomplete) -> Builder {
//            configuration.stateToItemsIncomplete = closure
//            return self
//        }
//
//        /// Must be configured to generate actual items.
//        @discardableResult
//        public func valueToItems(_ closure: @escaping Configuration.ValueToItems) -> Builder {
//            configuration.valueToItems = closure
//            return self
//        }
//
//        /// Must be configured to show items in the view.
//        @discardableResult
//        public func itemToView(_ closure: @escaping Configuration.ItemToView) -> Builder {
//            var itemToViewMapping = [Item.ViewType: ItemViewProducer]()
//            Item.ViewType.allCases.forEach { viewType in
//                itemToViewMapping[viewType] = closure(viewType)
//            }
//            configuration.itemToViewMapping = itemToViewMapping
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
//        public func loadingItem(_ closure: @escaping (ObservedState) -> Item) -> Builder {
//            configuration.loadingItem = closure
//            return self
//        }
//
//        @discardableResult
//        public func errorItem(_ closure: @escaping (E) -> Item) -> Builder {
//            configuration.errorItem = closure
//            return self
//        }
//
//        @discardableResult
//        public func noResultsItem(_ closure: @escaping (ObservedState) -> Item) -> Builder {
//            configuration.noResultsItem = closure
//            return self
//        }
//
//    }
//
//}
