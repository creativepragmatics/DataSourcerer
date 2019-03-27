import Foundation

// Holds closures of essential list view callbacks (mostly a minimal intersection
// of UITableViewDatasource and UICollectionViewDatasource).
//
// If you think a closure is missing (and you can therefore not use this struct
// for your own purposes), please create an issue at the Github page.
public struct ListViewDatasourceConfiguration
    <Value, P: ResourceParams, E, ItemModelType: ItemModel, ItemView: UIView,
    SectionModelType: SectionModel, HeaderItem: SupplementaryItemModel, HeaderItemView: UIView,
    HeaderItemError, FooterItem: SupplementaryItemModel, FooterItemView: UIView,
    FooterItemError, ContainingView: UIView> where ItemModelType.E == E, HeaderItem.E == HeaderItemError,
FooterItem.E == FooterItemError {
    public typealias ListState = ResourceState<Value, P, E>
    public typealias ItemViewAdapter = ItemViewsProducer<ItemModelType, ItemView, ContainingView>
    public typealias HeaderItemViewAdapter = ItemViewsProducer<HeaderItem, HeaderItemView, ContainingView>
    public typealias FooterItemViewAdapter = ItemViewsProducer<FooterItem, FooterItemView, ContainingView>
    public typealias StateAndSections = ListStateAndSections<ListState, ItemModelType, SectionModelType>
    public struct ItemSelection {
        public let itemModel: ItemModelType
        public let view: ItemView
        public let indexPath: IndexPath
        public let containingView: ContainingView
    }

    // MARK: - Definitions based on UITableViewDatasource & UICollectionViewDatasource
    public typealias HeaderItemAtIndexPath = (IndexPath) -> HeaderItem?
    public typealias FooterItemAtIndexPath = (IndexPath) -> FooterItem?
    public typealias TitleForHeaderInSection = (Int) -> String?
    public typealias TitleForFooterInSection = (Int) -> String?
    public typealias IndexTitles = () -> [String]?
    public typealias IndexPathForIndexTitle = (_ title: String, _ index: Int) -> IndexPath
    public typealias DidSelectItem = (ItemSelection) -> Void

    // MARK: - Definitions based on UITableViewDelegate & UICollectionViewDelegate
    public typealias WillDisplayItem = (ItemView, ItemModelType, IndexPath) -> Void
    public typealias WillDisplayHeaderItem =
        (HeaderItemView, HeaderItem, IndexPath) -> Void
    public typealias WillDisplayFooterItem =
        (FooterItemView, FooterItem, IndexPath) -> Void

    public let datasource: Datasource<Value, P, E>
    public let itemModelProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>
    public let stateAndSections: ShareableValueStream<StateAndSections>
    public let itemViewsProducer: ItemViewAdapter
    public let headerItemViewAdapter: HeaderItemViewAdapter
    public let footerItemViewAdapter: FooterItemViewAdapter

    // MARK: - Vars based on UITableViewDatasource & UICollectionViewDatasource
    public var headerItemAtIndexPath: HeaderItemAtIndexPath?
    public var footerItemAtIndexPath: FooterItemAtIndexPath?
    public var titleForHeaderInSection: TitleForHeaderInSection?
    public var titleForFooterInSection: TitleForFooterInSection?
    public var sectionIndexTitles: IndexTitles?
    public var indexPathForIndexTitle: IndexPathForIndexTitle?

    // MARK: - Vars based on UITableViewDelegate & UICollectionViewDelegate
    public var didSelectItem: DidSelectItem?
    public var willDisplayItem: WillDisplayItem?
    public var willDisplayHeaderItem: WillDisplayHeaderItem?
    public var willDisplayFooterItem: WillDisplayFooterItem?

    public init(datasource: Datasource<Value, P, E>,
                itemModelProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>,
                itemViewsProducer: ItemViewAdapter,
                headerItemViewAdapter: HeaderItemViewAdapter,
                footerItemViewAdapter: FooterItemViewAdapter,
                headerItemAtIndexPath: HeaderItemAtIndexPath?,
                footerItemAtIndexPath: FooterItemAtIndexPath?,
                titleForHeaderInSection: TitleForHeaderInSection?,
                titleForFooterInSection: TitleForFooterInSection?,
                sectionIndexTitles: IndexTitles?,
                indexPathForIndexTitle: IndexPathForIndexTitle?,
                didSelectItem: DidSelectItem?,
                willDisplayItem: WillDisplayItem?,
                willDisplayHeaderItem: WillDisplayHeaderItem?,
                willDisplayFooterItem: WillDisplayFooterItem?) {

        self.stateAndSections = datasource.state
            .map { state -> StateAndSections in
                return StateAndSections(
                    value: state,
                    listViewState: itemModelProducer.listViewState(with: state)
                )
            }
            .observeOnUIThread()
            .shareable(
                initialValue: StateAndSections(
                    value: datasource.state.value,
                    listViewState: itemModelProducer.listViewState(with: datasource.state.value)
                )
        )

        self.datasource = datasource
        self.itemModelProducer = itemModelProducer
        self.itemViewsProducer = itemViewsProducer
        self.headerItemViewAdapter = headerItemViewAdapter
        self.footerItemViewAdapter = footerItemViewAdapter
        self.headerItemAtIndexPath = headerItemAtIndexPath
        self.footerItemAtIndexPath = footerItemAtIndexPath
        self.titleForHeaderInSection = titleForHeaderInSection
        self.titleForFooterInSection = titleForFooterInSection
        self.sectionIndexTitles = sectionIndexTitles
        self.indexPathForIndexTitle = indexPathForIndexTitle
        self.didSelectItem = didSelectItem
        self.willDisplayItem = willDisplayItem
        self.willDisplayHeaderItem = willDisplayHeaderItem
        self.willDisplayFooterItem = willDisplayFooterItem
    }

}

/// Initially, a ListViewDatasourceConfiguration can do without headers and footers,
/// because those can be added via functions.
/// TODO: Add those functions
public extension ListViewDatasourceConfiguration where HeaderItem == NoSupplementaryItemModel,
    HeaderItemView == UIView, FooterItem == NoSupplementaryItemModel,
FooterItemView == UIView {

    init(
        datasource: Datasource<Value, P, E>,
        itemModelProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>,
        itemViewsProducer: ItemViewsProducer<ItemModelType, ItemView, ContainingView>
        ) {

        self.init(
            datasource: datasource,
            itemModelProducer: itemModelProducer,
            itemViewsProducer: itemViewsProducer,
            headerItemViewAdapter: .noSupplementaryViewAdapter,
            footerItemViewAdapter: .noSupplementaryViewAdapter,
            headerItemAtIndexPath: nil,
            footerItemAtIndexPath: nil,
            titleForHeaderInSection: nil,
            titleForFooterInSection: nil,
            sectionIndexTitles: nil,
            indexPathForIndexTitle: nil,
            didSelectItem: nil,
            willDisplayItem: nil,
            willDisplayHeaderItem: nil,
            willDisplayFooterItem: nil
        )
    }
}

public struct ListStateAndSections<Value, ItemModelType: ItemModel, SectionModelType: SectionModel> {
    public let value: Value
    public let listViewState: ListViewState<ItemModelType, SectionModelType>

    public init(value: Value, listViewState: ListViewState<ItemModelType, SectionModelType>) {
        self.value = value
        self.listViewState = listViewState
    }
}

public extension ListViewDatasourceConfiguration {

    var sections: ListViewState<ItemModelType, SectionModelType> {
        return stateAndSections.value.listViewState
    }

    func section(at index: Int) -> SectionAndItems<ItemModelType, SectionModelType> {
        let rawSection = sections.sectionedValues.sectionsAndValues[index]
        return SectionAndItems(rawSection.0, rawSection.1)
    }

    func item(at indexPath: IndexPath) -> ItemModelType {
        return items(in: indexPath.section)[indexPath.row]
    }

    func items(in section: Int) -> [ItemModelType] {
        return stateAndSections.value.listViewState
            .sectionedValues.sectionsAndValues[section].1
    }

    func itemView(at indexPath: IndexPath, in containingView: ContainingView) -> ItemView {
        return itemViewsProducer.produceView(item(at: indexPath), containingView, indexPath)
    }

    func headerView(at indexPath: IndexPath,
                    in containingView: ContainingView) -> HeaderItemView? {
        guard let item = headerItemAtIndexPath?(indexPath) else {
            return nil
        }

        return headerItemViewAdapter.produceView(item, containingView, indexPath)
    }

    func footerView(at indexPath: IndexPath,
                    in containingView: ContainingView) -> FooterItemView? {
        guard let item = footerItemAtIndexPath?(indexPath) else {
            return nil
        }

        return footerItemViewAdapter.produceView(item, containingView, indexPath)
    }

    func headerSize(at indexPath: IndexPath,
                    in containingView: ContainingView) -> CGSize {
        guard let item = headerItemAtIndexPath?(indexPath) else {
            return .zero
        }

        return headerItemViewAdapter.itemViewSize?(item, containingView) ?? .zero
    }

    func footerSize(at indexPath: IndexPath,
                    in containingView: ContainingView) -> CGSize {
        guard let item = footerItemAtIndexPath?(indexPath) else {
            return .zero
        }

        return footerItemViewAdapter.itemViewSize?(item, containingView) ?? .zero
    }

}

public extension ListViewDatasourceConfiguration {

    func onDidSelectItem(_ didSelectItem: @escaping DidSelectItem) -> ListViewDatasourceConfiguration {
        var mutableSelf = self
        mutableSelf.didSelectItem = didSelectItem
        return mutableSelf
    }
}

public extension ListViewDatasourceConfiguration {

    typealias ConfigurationWithLoadingAndErrorStates = ListViewDatasourceConfiguration
        <Value, P, E, IdiomaticItemModel<ItemModelType>, ItemView, SectionModelType,
        HeaderItem, HeaderItemView, HeaderItemError, FooterItem, FooterItemView, FooterItemError,
        ContainingView>

    func showLoadingAndErrorStates<ViewProducer: ItemViewProducer>(
        noResultsText: String,
        loadingViewProducer: ViewProducer,
        errorViewProducer: ViewProducer,
        noResultsViewProducer: ViewProducer
        )
        -> ConfigurationWithLoadingAndErrorStates
        where ViewProducer.ItemModelType == IdiomaticItemModel<ItemModelType>,
        ViewProducer.ProducedView == ItemView,
        ViewProducer.ContainingView == ContainingView, ItemModelType.E == E {

            let idiomaticItemModelsProducer = self.itemModelProducer.showLoadingAndErrorStates(
                noResultsText: noResultsText
            )

            let idiomaticItemViewAdapter = self.itemViewsProducer.showLoadingAndErrorStates(
                loadingViewProducer: loadingViewProducer,
                errorViewProducer: errorViewProducer,
                noResultsViewProducer: noResultsViewProducer
            )

            let idiomaticDidSelectItem: (ConfigurationWithLoadingAndErrorStates.DidSelectItem)?
            if let didSelectItem = self.didSelectItem {
                idiomaticDidSelectItem = { itemSelection in
                    switch itemSelection.itemModel {
                    case let .baseItem(baseItem):
                        let baseItemSelection = ItemSelection(
                            itemModel: baseItem,
                            view: itemSelection.view,
                            indexPath: itemSelection.indexPath,
                            containingView: itemSelection.containingView
                        )
                        didSelectItem(baseItemSelection)
                    case .loading, .error, .noResults:
                        // Currently, no click handling implemented.
                        break
                    }
                }
            } else {
                idiomaticDidSelectItem = nil
            }

            return ListViewDatasourceConfiguration
                <Value, P, E, IdiomaticItemModel<ItemModelType>, ItemView, SectionModelType,
                HeaderItem, HeaderItemView, HeaderItemError, FooterItem, FooterItemView,
                FooterItemError, ContainingView> (
                    datasource: datasource,
                    itemModelProducer: idiomaticItemModelsProducer,
                    itemViewsProducer: idiomaticItemViewAdapter,
                    headerItemViewAdapter: headerItemViewAdapter,
                    footerItemViewAdapter: footerItemViewAdapter,
                    headerItemAtIndexPath: headerItemAtIndexPath,
                    footerItemAtIndexPath: footerItemAtIndexPath,
                    titleForHeaderInSection: titleForHeaderInSection,
                    titleForFooterInSection: titleForFooterInSection,
                    sectionIndexTitles: sectionIndexTitles,
                    indexPathForIndexTitle: indexPathForIndexTitle,
                    didSelectItem: idiomaticDidSelectItem,
                    willDisplayItem: { itemView, item, indexPath in
                        switch item {
                        case let .baseItem(datasourceItem):
                            self.willDisplayItem?(itemView, datasourceItem, indexPath)
                        case .loading, .error, .noResults:
                            break
                        }
                },
                    willDisplayHeaderItem: willDisplayHeaderItem,
                    willDisplayFooterItem: willDisplayFooterItem
            )
    }
}

public typealias TableViewDatasourceConfiguration
    <Value, P: ResourceParams, E, Cell: ItemModel, CellView: UITableViewCell,
    Section: SectionModel, HeaderItem: SupplementaryItemModel, HeaderItemView: UIView,
    HeaderItemError, FooterItem: SupplementaryItemModel, FooterItemView: UIView,
    FooterItemError>
    =
    ListViewDatasourceConfiguration
    <Value, P, E, Cell, CellView, Section, HeaderItem, HeaderItemView, HeaderItemError,
    FooterItem, FooterItemView, FooterItemError, UITableView>
    where Cell.E == E, HeaderItem.E == HeaderItemError, FooterItem.E == FooterItemError

public extension TableViewDatasourceConfiguration where HeaderItem == NoSupplementaryItemModel,
    HeaderItemView == UIView, FooterItem == NoSupplementaryItemModel,
FooterItemView == UIView, ItemView == UITableViewCell {

    static func withBaseTableViewCell(
        datasource: Datasource<Value, P, E>,
        itemModelProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>,
        cellClass `class`: ItemView.Type,
        reuseIdentifier: String,
        configure: @escaping (ItemModelType, ItemView) -> Void)
        -> TableViewDatasourceConfiguration
        <Value, P, E, ItemModelType, ItemView, SectionModelType, NoSupplementaryItemModel, UIView,
        NoResourceError, NoSupplementaryItemModel, UIView, NoResourceError> {

            return TableViewDatasourceConfiguration(
                datasource: datasource,
                itemModelProducer: itemModelProducer,
                itemViewsProducer: TableViewCellAdapter<ItemModelType>.tableViewCell(
                    withCellClass: ItemView.self,
                    reuseIdentifier: reuseIdentifier, configure: configure
                )
            )
    }

}

// TODO: Move to List-UIKit folder as soon as XCode 10.2 is available:
// https://github.com/apple/swift/pull/18168
/// Builder.Complete for single section tableviews
public extension ListViewDatasourceConfiguration
    where Value: Equatable,
    ItemView == UITableViewCell,
    ContainingView == UITableView,
    HeaderItemView == UIView,
    FooterItemView == UIView,
SectionModelType == NoSection {

    var singleSectionTableViewController: SingleSectionTableViewController
        <Value, P, E, ItemModelType, HeaderItem, HeaderItemError, FooterItem, FooterItemError> {
        return SingleSectionTableViewController(configuration: self)
    }

}
