import DataSourcerer
import Foundation
import ReactiveSwift
import UIKit

public extension Resource.TableViewScope {
    struct SingleSectionScope {
        let tableViewScope: Resource.TableViewScope

        public var enhanced: EnhancedScope {
            .init(singleSectionScope: self)
        }
    }
}

public extension Resource.TableViewScope.SingleSectionScope {
    typealias BaseListBinding<ItemModelType: ItemModel> = Resource.ListBinding<
        ItemModelType,
        SingleSection,
        UITableViewCell,
        UITableView
    > where ItemModelType.Failure == Resource.FailureType

    typealias MakeBaseModelsWithResource<ItemModelType: ItemModel> =
        (Value, Resource.State) -> [ItemModelType]

    typealias TableViewCellMakerType<ItemModelType: ItemModel> =
        Resource.TableViewScope.TableViewCellMaker<ItemModelType, SingleSection>
    where ItemModelType.Failure == Resource.FailureType

    /// Creates a binding for one base cell view type within a single section.
    func makeBinding<ItemModelType: ItemModel>(
        makeBaseModelsWithResource: Property<MakeBaseModelsWithResource<ItemModelType>>,
        makeBaseTableViewCell: TableViewCellMakerType<ItemModelType>
    ) -> Resource.ListBinding<ItemModelType, SingleSection, UITableViewCell, UITableView>
    where Resource.FailureType == ItemModelType.Failure {

        let makeSingleSectionListViewState = BaseListBinding.ListViewStateMaker
            .singleSectionItems(makeBaseModelsWithResource)

        return tableViewScope
            .makeBinding(
                cellModelMaker: makeSingleSectionListViewState,
                cellViewMaker: makeBaseTableViewCell.itemMaker,
                sectionHeaderMaker: .constant(.none),
                sectionFooterMaker: .constant(.none)
            )
    }

    /// Creates a binding for multiple base cell view types within a single section.
    func makeBinding<ItemModelType: MultiViewTypeItemModel>(
        makeBaseModelsWithResource: Property<MakeBaseModelsWithResource<ItemModelType>>,
        multiCellViewMaker: (ItemModelType.ItemViewType)
            -> Property<BaseListBinding<ItemModelType>.UIViewItemMaker>
    ) -> Resource.ListBinding<ItemModelType, SingleSection, UITableViewCell, UITableView>
    where Resource.FailureType == ItemModelType.Failure {

        let makeSingleSectionListViewState = BaseListBinding.ListViewStateMaker
            .singleSectionItems(makeBaseModelsWithResource)

        return tableViewScope
            .makeBinding(
                cellModelMaker: makeSingleSectionListViewState,
                multiCellViewMaker: multiCellViewMaker,
                sectionHeaderMaker: .constant(.none),
                sectionFooterMaker: .constant(.none)
            )
    }
}

public extension Resource.TableViewScope.SingleSectionScope {
    struct EnhancedScope {
        let singleSectionScope: Resource.TableViewScope.SingleSectionScope
    }
}

public extension Resource.TableViewScope.SingleSectionScope.EnhancedScope {
    typealias BaseListBinding<ItemModelType: ItemModel> = Resource.ListBinding<
        ItemModelType,
        SingleSection,
        UITableViewCell,
        UITableView
    > where ItemModelType.Failure == Resource.FailureType

    typealias EnhancedListBinding<BaseItemModelType: ItemModel> =
        BaseListBinding<BaseItemModelType>.EnhancedListBinding
    where BaseItemModelType.Failure == Resource.FailureType

    typealias CellMaker<ItemModelType: ItemModel> =
        Resource.TableViewScope.TableViewCellMaker<ItemModelType, SingleSection>
    where ItemModelType.Failure == Resource.FailureType

    typealias EnhancedCellMaker<ItemModelType: ItemModel> = CellMaker<EnhancedItemModel<ItemModelType>>
    where ItemModelType.Failure == Resource.FailureType

    typealias MakeBaseModelsWithResource<ItemModelType: ItemModel> = (Value, Resource.State) -> [ItemModelType]

    func makeBinding<ItemModelType: ItemModel>(
        makeBaseModelsWithResource: Property<MakeBaseModelsWithResource<ItemModelType>>,
        makeBaseTableViewCell: CellMaker<ItemModelType>,
        errorsConfiguration: Property<EnhancedListViewStateErrorsConfiguration>,
        makeLoadingTableViewCell: EnhancedCellMaker<ItemModelType>?,
        makeErrorTableViewCell: EnhancedCellMaker<ItemModelType>?,
        makeNoResultsTableViewCell: EnhancedCellMaker<ItemModelType>?
    ) -> EnhancedListBinding<ItemModelType>
    where Resource.FailureType == ItemModelType.Failure {

        let makeSingleSectionListViewState = BaseListBinding.ListViewStateMaker
            .singleSectionItems(makeBaseModelsWithResource)

        let baseListBinding: BaseListBinding = singleSectionScope
            .tableViewScope
            .makeBinding(
                cellModelMaker: makeSingleSectionListViewState,
                cellViewMaker: makeBaseTableViewCell.itemMaker,
                sectionHeaderMaker: .constant(.none),
                sectionFooterMaker: .constant(.none)
            )
        return baseListBinding.enhance(
            errorsConfiguration: errorsConfiguration,
            loadingViewMaker: makeLoadingTableViewCell?.itemMaker,
            errorViewMaker: makeErrorTableViewCell?.itemMaker,
            noResultsViewMaker: makeNoResultsTableViewCell?.itemMaker
        )
    }

    func makeBinding<ItemModelType: MultiViewTypeItemModel>(
        makeBaseModelsWithResource:
            Property<MakeBaseModelsWithResource<ItemModelType>>,
        makeMultiBaseTableViewCells: (ItemModelType.ItemViewType)
            -> CellMaker<ItemModelType>,
        errorsConfiguration: Property<EnhancedListViewStateErrorsConfiguration>,
        makeLoadingTableViewCell: EnhancedCellMaker<ItemModelType>?,
        makeErrorTableViewCell: EnhancedCellMaker<ItemModelType>?,
        makeNoResultsTableViewCell: EnhancedCellMaker<ItemModelType>?
    ) -> EnhancedListBinding<ItemModelType>
    where Resource.FailureType == ItemModelType.Failure {

        let makeSingleSectionListViewState = BaseListBinding.ListViewStateMaker
            .singleSectionItems(makeBaseModelsWithResource)

        typealias TargetMultiCellMaker = (ItemModelType.ItemViewType)
            -> Property<BaseListBinding<ItemModelType>.UIViewItemMaker>

        let multiCellViewMaker: TargetMultiCellMaker = { itemViewType in
            makeMultiBaseTableViewCells(itemViewType).itemMaker
        }

        let baseListBinding: BaseListBinding = singleSectionScope
            .tableViewScope
            .makeBinding(
                cellModelMaker: makeSingleSectionListViewState,
                multiCellViewMaker: multiCellViewMaker,
                sectionHeaderMaker: .constant(.none),
                sectionFooterMaker: .constant(.none)
            )
        return baseListBinding.enhance(
            errorsConfiguration: errorsConfiguration,
            loadingViewMaker: makeLoadingTableViewCell?.itemMaker,
            errorViewMaker: makeErrorTableViewCell?.itemMaker,
            noResultsViewMaker: makeNoResultsTableViewCell?.itemMaker
        )
    }
}
