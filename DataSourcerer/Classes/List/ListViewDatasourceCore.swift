import Foundation

// Holds closures of essential list view callbacks (mostly a minimal intersection
// of UITableViewDatasource and UICollectionViewDatasource).
//
// If you think a closure is missing (and you can therefore not use this struct
// for your own purposes), please create an issue at the Github page.
public struct ListViewDatasourceCore
    <Value, P: Parameters, E, Item: ListItem, ItemView: UIView,
    Section: ListSection, HeaderItem: SupplementaryItem, HeaderItemView: UIView,
    FooterItem: SupplementaryItem, FooterItemView: UIView,
ContainingView: UIView> where Item.E == E {
    public typealias ListState = State<Value, P, E>
    public typealias ItemViewAdapter = ListViewItemAdapter<Item, ItemView, ContainingView>
    public typealias HeaderItemViewAdapter = ListViewItemAdapter<HeaderItem, HeaderItemView, ContainingView>
    public typealias FooterItemViewAdapter = ListViewItemAdapter<FooterItem, FooterItemView, ContainingView>
    public typealias StateAndSections = ListStateAndSections<ListState, Item, Section>

    // MARK: - Definitions based on UITableViewDatasource & UICollectionViewDatasource
    public typealias HeaderItemAtIndexPath = (IndexPath) -> HeaderItem?
    public typealias FooterItemAtIndexPath = (IndexPath) -> FooterItem?
    public typealias TitleForHeaderInSection = (Int) -> String?
    public typealias TitleForFooterInSection = (Int) -> String?
    public typealias IndexTitles = () -> [String]?
    public typealias IndexPathForIndexTitle = (_ title: String, _ index: Int) -> IndexPath

    // MARK: - Definitions based on UITableViewDelegate & UICollectionViewDelegate
    public typealias WillDisplayItem = (ItemView, Item, IndexPath) -> Void
    public typealias WillDisplayHeaderItem =
        (HeaderItemView, HeaderItem, IndexPath) -> Void
    public typealias WillDisplayFooterItem =
        (FooterItemView, FooterItem, IndexPath) -> Void

    public let datasource: Datasource<Value, P, E>
    public let listItemProducer: ListItemProducer<Value, P, E, Item, Section>
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
                listItemProducer: ListItemProducer<Value, P, E, Item, Section>,
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
                    listViewState: listItemProducer.listViewState(with: state)
                )
            }
            .observeOnUIThread()
            .shareable(
                initialValue: StateAndSections(
                    value: datasource.state.value,
                    listViewState: listItemProducer.listViewState(with: datasource.state.value)
                )
        )

        self.datasource = datasource
        self.listItemProducer = listItemProducer
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

public extension ListViewDatasourceCore where HeaderItem == NoSupplementaryItem,
    HeaderItemView == UIView, FooterItem == NoSupplementaryItem,
FooterItemView == UIView {

    static func base(
        datasource: Datasource<Value, P, E>,
        listItemProducer: ListItemProducer<Value, P, E, Item, Section>,
        itemViewAdapter: ListViewItemAdapter<Item, ItemView, ContainingView>)
        -> ListViewDatasourceCore
        <Value, P, E, Item, ItemView, Section, NoSupplementaryItem, UIView,
        NoSupplementaryItem, UIView, ContainingView> {

            return ListViewDatasourceCore(
                datasource: datasource,
                listItemProducer: listItemProducer,
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

public struct ListStateAndSections<Value, Item: ListItem, Section: ListSection> {
    public let value: Value
    public let listViewState: ListViewState<Item, Section>

    public init(value: Value, listViewState: ListViewState<Item, Section>) {
        self.value = value
        self.listViewState = listViewState
    }
}

public extension ListViewDatasourceCore {

    var sections: ListViewState<Item, Section> {
        return stateAndSections.value.listViewState
    }

    func section(at index: Int) -> SectionWithItems<Item, Section> {
        let rawSection = sections.sectionedValues.sectionsAndValues[index]
        return SectionWithItems(rawSection.0, rawSection.1)
    }

    func item(at indexPath: IndexPath) -> Item {
        return items(in: indexPath.section)[indexPath.row]
    }

    func items(in section: Int) -> [Item] {
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

    func idiomatic<ViewProducer: ListItemViewProducer>(
        noResultsText: String,
        loadingViewProducer: ViewProducer,
        errorViewProducer: ViewProducer,
        noResultsViewProducer: ViewProducer
        )
        -> ListViewDatasourceCore<Value, P, E, IdiomaticListItem<Item>, ItemView, Section,
        HeaderItem, HeaderItemView, FooterItem, FooterItemView, ContainingView>
        where ViewProducer.Item == IdiomaticListItem<Item>,
        ViewProducer.ProducedView == ItemView,
        ViewProducer.ContainingView == ContainingView, Item.E == E {

            let idiomaticListItemProducer = self.listItemProducer.idiomatic(
                noResultsText: noResultsText
            )

            let idiomaticItemViewAdapter = self.itemViewAdapter.idiomatic(
                loadingViewProducer: loadingViewProducer,
                errorViewProducer: errorViewProducer,
                noResultsViewProducer: noResultsViewProducer
            )

            return ListViewDatasourceCore
                <Value, P, E, IdiomaticListItem<Item>, ItemView,
                Section, HeaderItem, HeaderItemView, FooterItem, FooterItemView,
                ContainingView> (
                    datasource: datasource,
                    listItemProducer: idiomaticListItemProducer,
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
    <Value, P: Parameters, E, Cell: ListItem, CellView: UITableViewCell,
    Section: ListSection, HeaderItem: SupplementaryItem, HeaderItemView: UIView,
    FooterItem: SupplementaryItem, FooterItemView: UIView>
    =
    ListViewDatasourceCore
    <Value, P, E, Cell, CellView, Section, HeaderItem, HeaderItemView,
    FooterItem, FooterItemView, UITableView> where Cell.E == E

public extension TableViewDatasourceCore where HeaderItem == NoSupplementaryItem,
    HeaderItemView == UIView, FooterItem == NoSupplementaryItem,
    FooterItemView == UIView, ItemView == UITableViewCell {

    static func withBaseTableViewCell(
        datasource: Datasource<Value, P, E>,
        listItemProducer: ListItemProducer<Value, P, E, Item, Section>,
        cellClass `class`: ItemView.Type,
        reuseIdentifier: String,
        configure: @escaping (Item, ItemView) -> Void)
        -> TableViewDatasourceCore
        <Value, P, E, Item, ItemView, Section, NoSupplementaryItem, UIView,
        NoSupplementaryItem, UIView> {

            return TableViewDatasourceCore.base(
                datasource: datasource,
                listItemProducer: listItemProducer,
                itemViewAdapter: TableViewCellAdapter<Item>.tableViewCell(
                    withCellClass: ItemView.self,
                    reuseIdentifier: reuseIdentifier, configure: configure
                )
            )
    }

}
