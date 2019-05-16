import Foundation

public struct TableViewBehavior
    <Value, P: ResourceParams, E, ItemModelType: ItemModel, SectionModelType: SectionModel>
    where ItemModelType.E == E {

    public typealias ItemViewsProducerAlias = ItemViewsProducer<ItemModelType, UITableViewCell, UITableView>
    public typealias ItemModelsProducerAlias = ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>

    let itemModelsProducer: ItemModelsProducerAlias
    let itemViewsProducer: ItemViewsProducerAlias

    init(itemModelsProducer: ItemModelsProducerAlias, itemViewsProducer: ItemViewsProducerAlias) {
        self.itemModelsProducer = itemModelsProducer
        self.itemViewsProducer = itemViewsProducer
    }

    func showLoadingAndErrors(
        configuration: ShowLoadingAndErrorsConfiguration,
        loadingViewProducer: TableViewCellProducer<IdiomaticItemModel<ItemModelType>>,
        errorViewProducer: TableViewCellProducer<IdiomaticItemModel<ItemModelType>>,
        noResultsViewProducer: TableViewCellProducer<IdiomaticItemModel<ItemModelType>>,
        noResultsText: String
        ) -> TableViewBehavior<Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType> {

        let itemViewsProducer = self.itemViewsProducer.showLoadingAndErrorStates(
            configuration: configuration,
            loadingViewProducer: loadingViewProducer,
            errorViewProducer: errorViewProducer,
            noResultsViewProducer: noResultsViewProducer
        )

        let itemModelsProducer = self.itemModelsProducer.showLoadingAndErrorStates(
            configuration: configuration, noResultsText: noResultsText
        )

        return TableViewBehavior<Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType>(
            itemModelsProducer: itemModelsProducer,
            itemViewsProducer: itemViewsProducer
        )
    }
}
