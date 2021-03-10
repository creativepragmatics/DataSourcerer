import DataSourcerer
import DifferenceKit
import Foundation
import ReactiveSwift
import UIKit

public extension Resource.TableViewScope {
    struct MultiSectionScope {
        let tableViewScope: Resource.TableViewScope

        public var enhanced: EnhancedScope {
            .init(multiSectionScope: self)
        }
    }
}

public extension Resource.TableViewScope.MultiSectionScope {
    typealias BaseListBinding<ItemModelType: ItemModel, SectionModelType: SectionModel> =
        Resource.ListBinding<
            ItemModelType,
            SectionModelType,
            UITableViewCell,
            UITableView
        > where ItemModelType.Failure == Resource.FailureType

    typealias MakeBaseSectionsWithResource<
        ItemModelType: ItemModel,
        SectionModelType: SectionModel
    > = (Value, Resource.State) -> [ArraySection<SectionModelType, ItemModelType>]

    typealias TableViewCellMakerType<ItemModelType: ItemModel, SectionModelType: SectionModel> =
        Resource.TableViewScope.TableViewCellMaker<ItemModelType, SectionModelType>
    where ItemModelType.Failure == Resource.FailureType

    typealias SupplementaryViewMakerType<ItemModelType: ItemModel, SectionModelType: SectionModel> =
        Property<Resource.TableViewScope.TableViewSupplementaryViewMaker<ItemModelType, SectionModelType>>
    where ItemModelType.Failure == Resource.FailureType

    func makeBinding<ItemModelType: ItemModel, SectionModelType: SectionModel>(
        makeBaseModelsWithResource: Property<
            MakeBaseSectionsWithResource<ItemModelType, SectionModelType>
        >,
        makeBaseTableViewCell: TableViewCellMakerType<ItemModelType, SectionModelType>,
        makeSectionHeader: SupplementaryViewMakerType<ItemModelType, SectionModelType>,
        makeSectionFooter: SupplementaryViewMakerType<ItemModelType, SectionModelType>
    ) -> Resource.ListBinding<ItemModelType, SectionModelType, UITableViewCell, UITableView>
    where Resource.FailureType == ItemModelType.Failure {

        let makeMultiSectionListViewState = BaseListBinding.ListViewStateMaker
            .multiSectionItems(makeBaseModelsWithResource)

        return tableViewScope
            .makeBinding(
                cellModelMaker: makeMultiSectionListViewState,
                cellViewMaker: makeBaseTableViewCell.itemMaker,
                sectionHeaderMaker: makeSectionHeader,
                sectionFooterMaker: makeSectionFooter
            )
    }
}

public extension Resource.TableViewScope.MultiSectionScope {
    struct EnhancedScope {
        let multiSectionScope: Resource.TableViewScope.MultiSectionScope
    }
}

public extension Resource.TableViewScope.MultiSectionScope.EnhancedScope {
    typealias BaseListBinding<ItemModelType: ItemModel, SectionModelType: SectionModel> =
        Resource.ListBinding<
            ItemModelType,
            SectionModelType,
            UITableViewCell,
            UITableView
        > where ItemModelType.Failure == Resource.FailureType

    typealias EnhancedListBinding<
        BaseItemModelType: ItemModel,
        BaseSectionModelType: SectionModel
    > = BaseListBinding<BaseItemModelType, BaseSectionModelType>.EnhancedListBinding
    where BaseItemModelType.Failure == Resource.FailureType

    typealias CellMaker<ItemModelType: ItemModel, SectionModelType: SectionModel> =
        Resource.TableViewScope.TableViewCellMaker<ItemModelType, SectionModelType>
    where ItemModelType.Failure == Resource.FailureType

    typealias EnhancedCellMaker<ItemModelType: ItemModel, SectionModelType: SectionModel> =
        CellMaker<EnhancedItemModel<ItemModelType>, SectionModelType>
    where ItemModelType.Failure == Resource.FailureType

    typealias SupplementaryViewMakerType<ItemModelType: ItemModel, SectionModelType: SectionModel> =
        Property<Resource.TableViewScope.TableViewSupplementaryViewMaker<ItemModelType, SectionModelType>>
    where ItemModelType.Failure == Resource.FailureType

    typealias MakeBaseSectionsWithResource<
        ItemModelType: ItemModel,
        SectionModelType: SectionModel
    > = (Value, Resource.State) -> [ArraySection<SectionModelType, ItemModelType>]

    func makeBinding<ItemModelType: ItemModel, SectionModelType: SectionModel>(
        makeBaseSectionsWithResource:
            Property<MakeBaseSectionsWithResource<ItemModelType, SectionModelType>>,
        makeBaseTableViewCell: CellMaker<ItemModelType, SectionModelType>,
        makeSectionHeader: SupplementaryViewMakerType<ItemModelType, SectionModelType>,
        makeSectionFooter: SupplementaryViewMakerType<ItemModelType, SectionModelType>,
        errorsConfiguration: Property<EnhancedListViewStateErrorsConfiguration>,
        makeLoadingTableViewCell: EnhancedCellMaker<ItemModelType, SectionModelType>?,
        makeErrorTableViewCell: EnhancedCellMaker<ItemModelType, SectionModelType>?,
        makeNoResultsTableViewCell: EnhancedCellMaker<ItemModelType, SectionModelType>?
    ) -> EnhancedListBinding<ItemModelType, SectionModelType>
    where Resource.FailureType == ItemModelType.Failure {

        let makeMultiSectionListViewState = BaseListBinding.ListViewStateMaker
            .multiSectionItems(makeBaseSectionsWithResource)

        let baseListBinding: BaseListBinding = multiSectionScope
            .tableViewScope
            .makeBinding(
                cellModelMaker: makeMultiSectionListViewState,
                cellViewMaker: makeBaseTableViewCell.itemMaker,
                sectionHeaderMaker: makeSectionHeader,
                sectionFooterMaker: makeSectionFooter
            )
        return baseListBinding.enhance(
            errorsConfiguration: errorsConfiguration,
            loadingViewMaker: makeLoadingTableViewCell?.itemMaker,
            errorViewMaker: makeErrorTableViewCell?.itemMaker,
            noResultsViewMaker: makeNoResultsTableViewCell?.itemMaker
        )
    }
}
