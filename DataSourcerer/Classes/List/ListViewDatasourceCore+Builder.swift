import Foundation

public extension ListViewDatasourceCore where HeaderItem == NoSupplementaryItemModel,
    HeaderItemView == UIView, FooterItem == NoSupplementaryItemModel,
    FooterItemView == UIView {

    public struct Builder {

        public static func with(
            datasource: Datasource<Value, P, E>,
            withItemModelType: ItemModelType.Type,
            withSectionModelType: SectionModelType.Type,
            withItemViewType: ItemView.Type
            ) -> DatasourceSelected {
            return DatasourceSelected(datasource: datasource)
        }

        public struct DatasourceSelected {
            let datasource: Datasource<Value, P, E>

            public func mapSectionedItemModels(
                _ sectionModels: @escaping (Value) -> [SectionAndItems<ItemModelType, SectionModelType>]
            ) -> ItemModelsProducerSelected {
                let itemModelsProducer = ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>(
                    baseValueToListViewStateTransformer:
                        ValueToListViewStateTransformer<Value, ItemModelType, SectionModelType>(
                            valueToSections: sectionModels
                    )
                )

                return ItemModelsProducerSelected(
                    previous: self,
                    itemModelsProducer: itemModelsProducer
                )
            }

        }

        public struct ItemModelsProducerSelected {
            let previous: DatasourceSelected
            let itemModelsProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>

            public func setItemViewsProducer(
                _ producer: ItemViewsProducer<ItemModelType, ItemView, ContainingView>
            ) -> ItemViewsProducerSelected {
                return ItemViewsProducerSelected(
                    previous: self,
                    itemViewsProducer: producer
                )
            }
        }

        public struct ItemViewsProducerSelected {
            let previous: ItemModelsProducerSelected
            let itemViewsProducer: ItemViewsProducer<ItemModelType, ItemView, ContainingView>

            public var core: ListViewDatasourceCore {
                return ListViewDatasourceCore(
                    datasource: previous.previous.datasource,
                    itemModelProducer: previous.itemModelsProducer,
                    itemViewsProducer: itemViewsProducer
                )
            }
        }

    }

}

/// Basic configuration for single section lists
public extension ListViewDatasourceCore.Builder.DatasourceSelected
    where HeaderItem == NoSupplementaryItemModel, HeaderItemView == UIView,
    FooterItem == NoSupplementaryItemModel, FooterItemView == UIView,
    SectionModelType == NoSection {

    func mapSingleSectionItemModels(
        _ itemModels: @escaping (Value) -> [ItemModelType]
        ) -> ListViewDatasourceCore.Builder.ItemModelsProducerSelected {
        let itemModelsProducer = ItemModelsProducer<Value, P, E, ItemModelType, NoSection>(
            baseValueToListViewStateTransformer:
            ValueToListViewStateTransformer<Value, ItemModelType, SectionModelType>(
                valueToSingleSectionItems: itemModels
            )
        )

        return ListViewDatasourceCore<Value, P, E, ItemModelType, ItemView,
        SectionModelType, HeaderItem, HeaderItemView,
        FooterItem, FooterItemView,
        ContainingView>.Builder.ItemModelsProducerSelected(
            previous: self,
            itemModelsProducer: itemModelsProducer
        )
    }
}

/// Basic configuration for sectioned tableviews
public extension ListViewDatasourceCore.Builder
    where HeaderItem == NoSupplementaryItemModel, HeaderItemView == UIView,
    FooterItem == NoSupplementaryItemModel, FooterItemView == UIView,
    ItemView == UITableViewCell, ContainingView == UITableView {

    public static func forSectionedTableView(
        datasource: Datasource<Value, P, E>,
        withItemModelType: ItemModelType.Type,
        withSectionModelType: SectionModelType.Type
        ) -> ListViewDatasourceCore.Builder.DatasourceSelected {

        return ListViewDatasourceCore.Builder.DatasourceSelected(datasource: datasource)
    }

}

public extension ListViewDatasourceCore.Builder.ItemModelsProducerSelected
    where HeaderItem == NoSupplementaryItemModel, HeaderItemView == UIView,
    FooterItem == NoSupplementaryItemModel, FooterItemView == UIView,
    ItemView == UITableViewCell, ContainingView == UITableView {

    public func cellWithClass(
        cellType: UITableViewCell.Type,
        dequeueIdentifier: String,
        configure: @escaping (ItemModelType, UITableViewCell) -> Void
        ) -> ListViewDatasourceCore.Builder.ItemViewsProducerSelected {

        let cellProducer = SimpleTableViewCellProducer.classAndIdentifier(
            class: cellType,
            identifier: dequeueIdentifier,
            configure: configure
        )

        let itemViewsProducer = ItemViewsProducer(simpleWithViewProducer: cellProducer)

        return ListViewDatasourceCore.Builder.ItemViewsProducerSelected(
            previous: self,
            itemViewsProducer: itemViewsProducer
        )
    }

    public func cellWithNib(
        nib: UINib,
        dequeueIdentifier: String,
        configure: @escaping (ItemModelType, UITableViewCell) -> Void
        ) -> ListViewDatasourceCore.Builder.ItemViewsProducerSelected {

        let cellProducer = SimpleTableViewCellProducer.nibAndIdentifier(
            nib: nib,
            identifier: dequeueIdentifier,
            configure: configure
        )

        let itemViewsProducer = ItemViewsProducer(simpleWithViewProducer: cellProducer)

        return ListViewDatasourceCore.Builder.ItemViewsProducerSelected(
            previous: self,
            itemViewsProducer: itemViewsProducer
        )
    }


    //case nibAndIdentifier(nib: UINib,
    //identifier: TableViewCellDequeueIdentifier,
    //configure: (Cell, UITableViewCell) -> Void)

}

/// Basic configuration for single section tableviews
public extension ListViewDatasourceCore
    where HeaderItem == NoSupplementaryItemModel, HeaderItemView == UIView,
    FooterItem == NoSupplementaryItemModel, FooterItemView == UIView,
    ItemView == UITableViewCell, ContainingView == UITableView,
    SectionModelType == NoSection {

    public static func buildSingleSectionTableView(
        datasource: Datasource<Value, P, E>,
        withCellModelType: ItemModelType.Type
        ) -> ListViewDatasourceCore.Builder.DatasourceSelected {

        return ListViewDatasourceCore.Builder.DatasourceSelected(datasource: datasource)
    }

}
