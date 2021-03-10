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
}
