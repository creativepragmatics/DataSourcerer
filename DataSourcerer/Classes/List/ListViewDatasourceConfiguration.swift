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
    public typealias State = ListViewState<Value, P, E, ItemModelType, SectionModelType>
    public typealias ItemViewAdapter = ItemViewsProducer<ItemModelType, ItemView, ContainingView>
    public typealias HeaderItemViewAdapter = ItemViewsProducer<HeaderItem, HeaderItemView, ContainingView>
    public typealias FooterItemViewAdapter = ItemViewsProducer<FooterItem, FooterItemView, ContainingView>
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
    public let state: ShareableValueStream<State>
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

        self.state = datasource.state
            .map { resourceState -> State in
                return itemModelProducer.listViewState(with: resourceState)
            }
            .observeOnUIThread()
            .shareable(
                initialValue: itemModelProducer.listViewState(with: datasource.state.value)
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

public extension ListViewDatasourceConfiguration {

    func section(at index: Int) -> SectionAndItems<ItemModelType, SectionModelType> {
        let rawSection = state.value.sectionedValues.sectionsAndValues[index]
        return SectionAndItems(rawSection.0, rawSection.1)
    }

    func item(at indexPath: IndexPath) -> ItemModelType {
        return items(in: indexPath.section)[indexPath.row]
    }

    func items(in section: Int) -> [ItemModelType] {
        let sections = state.value.sectionedValues.sectionsAndValues[section].1
        return sections
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

    func onWillDisplayItem(_ willDisplayItem: @escaping WillDisplayItem) -> ListViewDatasourceConfiguration {
        var mutableSelf = self
        mutableSelf.willDisplayItem = willDisplayItem
        return mutableSelf
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
