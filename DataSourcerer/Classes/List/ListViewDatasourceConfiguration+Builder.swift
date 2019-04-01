import Foundation

public extension ListViewDatasourceConfiguration
    where
    Value: Equatable,
    HeaderItem == NoSupplementaryItemModel,
    HeaderItemView == UIView,
    FooterItem == NoSupplementaryItemModel,
    FooterItemView == UIView {

    struct Builder {

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
                        ValueToListViewStateTransformer<Value, P, ItemModelType, SectionModelType>(
                            valueToSections: sectionModels
                    )
                )

                return ItemModelsProducerSelected(
                    previous: self,
                    itemModelsProducer: itemModelsProducer
                )
            }

            public func setItemModelsProducer(
                _ itemModelsProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>
            ) -> ListViewDatasourceConfiguration.Builder.ItemModelsProducerSelected {

                return ListViewDatasourceConfiguration.Builder.ItemModelsProducerSelected(
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
            ) -> Complete {
                return Complete(
                    previous: self,
                    itemViewsProducer: producer
                )
            }
        }

        public struct Complete {
            let previous: ItemModelsProducerSelected
            let itemViewsProducer: ItemViewsProducer<ItemModelType, ItemView, ContainingView>

            public var configurationForFurtherCustomization: ListViewDatasourceConfiguration {
                return ListViewDatasourceConfiguration(
                    datasource: previous.previous.datasource,
                    itemModelProducer: previous.itemModelsProducer,
                    itemViewsProducer: itemViewsProducer
                )
            }
        }

    }

}

/// Builder for tableviews
public extension ListViewDatasourceConfiguration.Builder
    where HeaderItem == NoSupplementaryItemModel, HeaderItemView == UIView,
    FooterItem == NoSupplementaryItemModel, FooterItemView == UIView,
    ItemView == UITableViewCell, ContainingView == UITableView {

    static func forSectionedTableView(
        datasource: Datasource<Value, P, E>,
        withItemModelType: ItemModelType.Type,
        withSectionModelType: SectionModelType.Type
        ) -> ListViewDatasourceConfiguration.Builder.DatasourceSelected {

        return ListViewDatasourceConfiguration.Builder.DatasourceSelected(datasource: datasource)
    }

}

/// Basic configuration for single section lists
public extension ListViewDatasourceConfiguration.Builder.DatasourceSelected
    where HeaderItem == NoSupplementaryItemModel, HeaderItemView == UIView,
    FooterItem == NoSupplementaryItemModel, FooterItemView == UIView,
    SectionModelType == NoSection {

    func mapSingleSectionItemModels(
        _ itemModels: @escaping (Value, LoadImpulse<P>) -> [ItemModelType]
        ) -> ListViewDatasourceConfiguration.Builder.ItemModelsProducerSelected {
        let itemModelsProducer = ItemModelsProducer<Value, P, E, ItemModelType, NoSection>(
            baseValueToListViewStateTransformer:
            ValueToListViewStateTransformer<Value, P, ItemModelType, SectionModelType>(
                valueToSingleSectionItems: itemModels
            )
        )

        return ListViewDatasourceConfiguration.Builder.ItemModelsProducerSelected(
            previous: self,
            itemModelsProducer: itemModelsProducer
        )
    }

}

/// Builder.ItemModelsProducerSelected for tableviews
public extension ListViewDatasourceConfiguration.Builder.ItemModelsProducerSelected
    where HeaderItem == NoSupplementaryItemModel,
    HeaderItemView == UIView,
    FooterItem == NoSupplementaryItemModel,
    FooterItemView == UIView,
    ItemView == UITableViewCell,
    ContainingView == UITableView {

    func renderWithCellClass(
        cellType: UITableViewCell.Type,
        dequeueIdentifier: String,
        configure: @escaping (ItemModelType, UITableViewCell) -> Void
        ) -> ListViewDatasourceConfiguration.Builder.Complete {

        let cellProducer = SimpleTableViewCellProducer.classAndIdentifier(
            class: cellType,
            identifier: dequeueIdentifier,
            configure: configure
        )

        let itemViewsProducer = ItemViewsProducer(simpleWithViewProducer: cellProducer)

        return ListViewDatasourceConfiguration.Builder.Complete(
            previous: self,
            itemViewsProducer: itemViewsProducer
        )
    }

    func renderWithNib(
        nib: UINib,
        dequeueIdentifier: String,
        configure: @escaping (ItemModelType, UITableViewCell) -> Void
        ) -> ListViewDatasourceConfiguration.Builder.Complete {

        let cellProducer = SimpleTableViewCellProducer.nibAndIdentifier(
            nib: nib,
            identifier: dequeueIdentifier,
            configure: configure
        )

        let itemViewsProducer = ItemViewsProducer(simpleWithViewProducer: cellProducer)

        return ListViewDatasourceConfiguration.Builder.Complete(
            previous: self,
            itemViewsProducer: itemViewsProducer
        )
    }

}

/// Basic configuration for single section tableviews
public extension ListViewDatasourceConfiguration
    where Value: Equatable,
    HeaderItem == NoSupplementaryItemModel,
    HeaderItemView == UIView,
    FooterItem == NoSupplementaryItemModel,
    FooterItemView == UIView,
    ItemView == UITableViewCell,
    ContainingView == UITableView,
    SectionModelType == NoSection {

    static func buildSingleSectionTableView(
        datasource: Datasource<Value, P, E>,
        withCellModelType: ItemModelType.Type
        ) -> ListViewDatasourceConfiguration.Builder.DatasourceSelected {

        return ListViewDatasourceConfiguration.Builder.DatasourceSelected(datasource: datasource)
    }

}

// TODO: Move to List-UIKit folder as soon as XCode 10.2 is available:
// https://github.com/apple/swift/pull/18168
/// Builder.Complete for single section tableviews
public extension ListViewDatasourceConfiguration.Builder.Complete
    where HeaderItemView == UIView,
    FooterItemView == UIView,
    ItemView == UITableViewCell,
    SectionModelType == NoSection,
    HeaderItem == NoSupplementaryItemModel,
    FooterItem == NoSupplementaryItemModel,
    ContainingView == UITableView {

    var singleSectionTableViewController:
        SingleSectionTableViewController
        <Value, P, E, ItemModelType, HeaderItem, HeaderItemError, FooterItem, FooterItemError> {
        return SingleSectionTableViewController(configuration: self.configurationForFurtherCustomization)
    }

}
