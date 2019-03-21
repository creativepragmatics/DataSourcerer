import Foundation

// Holds closures of essential list view callbacks (mostly a minimal intersection
// of UITableViewDatasource and UICollectionViewDatasource).
//
// If you think a closure is missing (and you can therefore not use this struct
// for your own purposes), please create an issue at the Github page.
public struct ListViewDatasourceCore
    <Value, P: ResourceParams, E, ItemModelType: ItemModel, ItemView: UIView,
    SectionModelType: SectionModel, HeaderItem: SupplementaryItemModel, HeaderItemView: UIView,
    FooterItem: SupplementaryItemModel, FooterItemView: UIView,
ContainingView: UIView> where ItemModelType.E == E {
    public typealias ListState = ResourceState<Value, P, E>
    public typealias ItemViewAdapter = ItemViewsProducer<ItemModelType, ItemView, ContainingView>
    public typealias HeaderItemViewAdapter = ItemViewsProducer<HeaderItem, HeaderItemView, ContainingView>
    public typealias FooterItemViewAdapter = ItemViewsProducer<FooterItem, FooterItemView, ContainingView>
    public typealias StateAndSections = ListStateAndSections<ListState, ItemModelType, SectionModelType>

    // MARK: - Definitions based on UITableViewDatasource & UICollectionViewDatasource
    public typealias HeaderItemAtIndexPath = (IndexPath) -> HeaderItem?
    public typealias FooterItemAtIndexPath = (IndexPath) -> FooterItem?
    public typealias TitleForHeaderInSection = (Int) -> String?
    public typealias TitleForFooterInSection = (Int) -> String?
    public typealias IndexTitles = () -> [String]?
    public typealias IndexPathForIndexTitle = (_ title: String, _ index: Int) -> IndexPath

    // MARK: - Definitions based on UITableViewDelegate & UICollectionViewDelegate
    public typealias WillDisplayItem = (ItemView, ItemModelType, IndexPath) -> Void
    public typealias WillDisplayHeaderItem =
        (HeaderItemView, HeaderItem, IndexPath) -> Void
    public typealias WillDisplayFooterItem =
        (FooterItemView, FooterItem, IndexPath) -> Void

    public let datasource: Datasource<Value, P, E>
    public let itemModelProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>
    public let stateAndSections: ShareableValueStream<StateAndSections>
    public let itemViewAdapter: ItemViewAdapter
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
    public var willDisplayItem: WillDisplayItem?
    public var willDisplayHeaderItem: WillDisplayHeaderItem?
    public var willDisplayFooterItem: WillDisplayFooterItem?

    public init(datasource: Datasource<Value, P, E>,
                itemModelProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>,
                itemViewAdapter: ItemViewAdapter,
                headerItemViewAdapter: HeaderItemViewAdapter,
                footerItemViewAdapter: FooterItemViewAdapter,
                headerItemAtIndexPath: HeaderItemAtIndexPath?,
                footerItemAtIndexPath: FooterItemAtIndexPath?,
                titleForHeaderInSection: TitleForHeaderInSection?,
                titleForFooterInSection: TitleForFooterInSection?,
                sectionIndexTitles: IndexTitles?,
                indexPathForIndexTitle: IndexPathForIndexTitle?,
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
        self.itemViewAdapter = itemViewAdapter
        self.headerItemViewAdapter = headerItemViewAdapter
        self.footerItemViewAdapter = footerItemViewAdapter
        self.headerItemAtIndexPath = headerItemAtIndexPath
        self.footerItemAtIndexPath = footerItemAtIndexPath
        self.titleForHeaderInSection = titleForHeaderInSection
        self.titleForFooterInSection = titleForFooterInSection
        self.sectionIndexTitles = sectionIndexTitles
        self.indexPathForIndexTitle = indexPathForIndexTitle
        self.willDisplayItem = willDisplayItem
        self.willDisplayHeaderItem = willDisplayHeaderItem
        self.willDisplayFooterItem = willDisplayFooterItem
    }

}

public extension ListViewDatasourceCore where HeaderItem == NoSupplementaryItemModel,
    HeaderItemView == UIView, FooterItem == NoSupplementaryItemModel,
FooterItemView == UIView {

    static func base(
        datasource: Datasource<Value, P, E>,
        itemModelProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>,
        itemViewAdapter: ItemViewsProducer<ItemModelType, ItemView, ContainingView>)
        -> ListViewDatasourceCore {

            return ListViewDatasourceCore(
                datasource: datasource,
                itemModelProducer: itemModelProducer,
                itemViewAdapter: itemViewAdapter,
                headerItemViewAdapter: .noSupplementaryViewAdapter,
                footerItemViewAdapter: .noSupplementaryViewAdapter,
                headerItemAtIndexPath: nil,
                footerItemAtIndexPath: nil,
                titleForHeaderInSection: nil,
                titleForFooterInSection: nil,
                sectionIndexTitles: nil,
                indexPathForIndexTitle: nil,
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

public extension ListViewDatasourceCore {

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
        return itemViewAdapter.produceView(item(at: indexPath), containingView, indexPath)
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

public extension ListViewDatasourceCore {

    func idiomatic<ViewProducer: ItemViewProducer>(
        noResultsText: String,
        loadingViewProducer: ViewProducer,
        errorViewProducer: ViewProducer,
        noResultsViewProducer: ViewProducer
        )
        -> ListViewDatasourceCore<Value, P, E, IdiomaticItemModel<ItemModelType>, ItemView, SectionModelType,
        HeaderItem, HeaderItemView, FooterItem, FooterItemView, ContainingView>
        where ViewProducer.ItemModelType == IdiomaticItemModel<ItemModelType>,
        ViewProducer.ProducedView == ItemView,
        ViewProducer.ContainingView == ContainingView, ItemModelType.E == E {

            let idiomaticItemModelsProducer = self.itemModelProducer.idiomatic(
                noResultsText: noResultsText
            )

            let idiomaticItemViewAdapter = self.itemViewAdapter.idiomatic(
                loadingViewProducer: loadingViewProducer,
                errorViewProducer: errorViewProducer,
                noResultsViewProducer: noResultsViewProducer
            )

            return ListViewDatasourceCore
                <Value, P, E, IdiomaticItemModel<ItemModelType>, ItemView,
                SectionModelType, HeaderItem, HeaderItemView, FooterItem, FooterItemView,
                ContainingView> (
                    datasource: datasource,
                    itemModelProducer: idiomaticItemModelsProducer,
                    itemViewAdapter: idiomaticItemViewAdapter,
                    headerItemViewAdapter: headerItemViewAdapter,
                    footerItemViewAdapter: footerItemViewAdapter,
                    headerItemAtIndexPath: headerItemAtIndexPath,
                    footerItemAtIndexPath: footerItemAtIndexPath,
                    titleForHeaderInSection: titleForHeaderInSection,
                    titleForFooterInSection: titleForFooterInSection,
                    sectionIndexTitles: sectionIndexTitles,
                    indexPathForIndexTitle: indexPathForIndexTitle,
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

public typealias TableViewDatasourceCore
    <Value, P: ResourceParams, E, Cell: ItemModel, CellView: UITableViewCell,
    Section: SectionModel, HeaderItem: SupplementaryItemModel, HeaderItemView: UIView,
    FooterItem: SupplementaryItemModel, FooterItemView: UIView>
    =
    ListViewDatasourceCore
    <Value, P, E, Cell, CellView, Section, HeaderItem, HeaderItemView,
    FooterItem, FooterItemView, UITableView> where Cell.E == E

public extension TableViewDatasourceCore where HeaderItem == NoSupplementaryItemModel,
    HeaderItemView == UIView, FooterItem == NoSupplementaryItemModel,
    FooterItemView == UIView, ItemView == UITableViewCell {

    static func withBaseTableViewCell(
        datasource: Datasource<Value, P, E>,
        itemModelProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>,
        cellClass `class`: ItemView.Type,
        reuseIdentifier: String,
        configure: @escaping (ItemModelType, ItemView) -> Void)
        -> TableViewDatasourceCore
        <Value, P, E, ItemModelType, ItemView, SectionModelType, NoSupplementaryItemModel, UIView,
        NoSupplementaryItemModel, UIView> {

            return TableViewDatasourceCore.base(
                datasource: datasource,
                itemModelProducer: itemModelProducer,
                itemViewAdapter: TableViewCellAdapter<ItemModelType>.tableViewCell(
                    withCellClass: ItemView.self,
                    reuseIdentifier: reuseIdentifier, configure: configure
                )
            )
    }

}
