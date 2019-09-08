import Foundation
import UIKit

extension UITableView: SourcererExtensionsProvider {}

public extension SourcererExtension where Base: UITableView {

    @discardableResult
    func bindToDatasource
        <Value, P: ResourceParams, E: ResourceError, BaseItemModelType,
        SectionModelType, FinalItemModelType: ItemModel> (
        _ dataSource: Datasource<Value, P, E>,
        itemModelsProducer: ItemModelsProducer<Value, P, E, BaseItemModelType, SectionModelType>,
        itemViewsProducer: ItemViewsProducer<BaseItemModelType, UITableViewCell, UITableView>,
        configureBehavior: (TableViewBehavior<Value, P, E, BaseItemModelType, SectionModelType>)
            -> TableViewBehavior<Value, P, E, FinalItemModelType, SectionModelType>,
        animateCellContentChange: @escaping (FinalItemModelType, UITableView, IndexPath) -> Bool
    ) -> TableViewBindingSource
        <Value, P, E, FinalItemModelType, SectionModelType,
        NoSupplementaryItemModel, NoResourceError, NoSupplementaryItemModel, NoResourceError> {

            unbindFromDatasource()

            let baseBehavior = TableViewBehavior(
                itemModelsProducer: itemModelsProducer,
                itemViewsProducer: itemViewsProducer
            )

            let finalBehavior = configureBehavior(baseBehavior)

            let configuration = ListViewDatasourceConfiguration(
                datasource: dataSource,
                itemModelProducer: finalBehavior.itemModelsProducer,
                itemViewsProducer: finalBehavior.itemViewsProducer
            )

            let tableViewBindingSource = TableViewBindingSource(
                configuration: configuration,
                animateCellContentChange: animateCellContentChange
            )

            tableViewBindingSource.bind(tableView: base)

            // Retain tableViewBindingSource until it is actively unbound,
            // or bind() is called again.
            base.unbindable = tableViewBindingSource

            return tableViewBindingSource
    }

    @discardableResult
    func bindToDatasource
        <Value, P: ResourceParams, E: ResourceError, BaseItemModelType,
        SectionModelType>
    (
        _ dataSource: Datasource<Value, P, E>,
        itemModelsProducer: ItemModelsProducer<Value, P, E, BaseItemModelType, SectionModelType>,
        itemViewsProducer: ItemViewsProducer<BaseItemModelType, UITableViewCell, UITableView>,
        animateCellContentChange: @escaping (BaseItemModelType, UITableView, IndexPath)
            -> Bool = { _, _, _ in false }
    ) -> TableViewBindingSource
        <Value, P, E, BaseItemModelType, SectionModelType,
        NoSupplementaryItemModel, NoResourceError, NoSupplementaryItemModel, NoResourceError> {

            return bindToDatasource(
                dataSource,
                itemModelsProducer: itemModelsProducer,
                itemViewsProducer: itemViewsProducer,
                configureBehavior: { $0 },
                animateCellContentChange: animateCellContentChange
            )
    }

    func prepareBindingToDatasource
        <Value, P: ResourceParams, E: ResourceError, BaseItemModelType,
        SectionModelType>
    (
        _ dataSource: Datasource<Value, P, E>,
        baseItemModelType: BaseItemModelType.Type,
        sectionModelType: SectionModelType.Type
    ) -> TableViewBindingStepOne<Value, P, E, BaseItemModelType, SectionModelType>
        where BaseItemModelType.E == E {

        return TableViewBindingStepOne(tableView: base, dataSource: dataSource)
    }

    struct TableViewBindingStepOne
        <Value, P: ResourceParams, E, BaseItemModelType: ItemModel,
    SectionModelType: SectionModel> where BaseItemModelType.E == E {

        let tableView: UITableView
        let dataSource: Datasource<Value, P, E>

        public func setItemModelsProducer(
            _ producer: ItemModelsProducer<Value, P, E, BaseItemModelType, SectionModelType>
        ) -> TableViewBindingStepTwo<Value, P, E, BaseItemModelType, SectionModelType> {
            return TableViewBindingStepTwo(
                tableView: tableView,
                dataSource: dataSource,
                itemModelsProducer: producer
            )
        }
    }

    struct TableViewBindingStepTwo
        <Value, P: ResourceParams, E, BaseItemModelType: ItemModel,
    SectionModelType: SectionModel> where BaseItemModelType.E == E {

        let tableView: UITableView
        let dataSource: Datasource<Value, P, E>
        let itemModelsProducer: ItemModelsProducer<Value, P, E, BaseItemModelType, SectionModelType>

        public func setItemViewsProducer(
            _ producer: ItemViewsProducer<BaseItemModelType, UITableViewCell, UITableView>
        ) -> TableViewBindingReady<Value, P, E, BaseItemModelType, SectionModelType> {

            return TableViewBindingReady(
                tableView: tableView,
                dataSource: dataSource,
                itemModelsProducer: itemModelsProducer,
                itemViewsProducer: producer
            )
        }
    }

    struct TableViewBindingReady
        <Value, P: ResourceParams, E, ItemModelType: ItemModel,
        SectionModelType: SectionModel> where ItemModelType.E == E {

        let tableView: UITableView
        let dataSource: Datasource<Value, P, E>
        let itemModelsProducer: ItemModelsProducer<Value, P, E, ItemModelType, SectionModelType>
        let itemViewsProducer: ItemViewsProducer<ItemModelType, UITableViewCell, UITableView>

        @discardableResult
        public func bind(
            animateCellContentChange: @escaping (ItemModelType, UITableView, IndexPath)
                -> Bool = { _, _, _ in false }
        ) -> TableViewBindingSource
            <Value, P, E, ItemModelType, SectionModelType,
            NoSupplementaryItemModel, NoResourceError, NoSupplementaryItemModel, NoResourceError> {
            return tableView.sourcerer.bindToDatasource(
                dataSource,
                itemModelsProducer: itemModelsProducer,
                itemViewsProducer: itemViewsProducer,
                configureBehavior: { $0 },
                animateCellContentChange: animateCellContentChange
            )
        }
    }

    func unbindFromDatasource() {
        base.unbindable?.unbind(from: base)
    }

}

public extension SourcererExtension.TableViewBindingStepOne {

    func singleSection(
        _ singleSectionItems: @escaping (Value, ResourceState<Value, P, E>) -> [BaseItemModelType]
    ) -> SourcererExtension.TableViewBindingStepTwo<Value, P, E, BaseItemModelType, SingleSection> {

        return SourcererExtension.TableViewBindingStepTwo(
            tableView: tableView,
            dataSource: dataSource,
            itemModelsProducer: ItemModelsProducer.singleSectionItems(singleSectionItems)
        )
    }
}

public extension SourcererExtension.TableViewBindingStepTwo {

    func cellsWithClass<CellView: UITableViewCell>(
        _ `class`: CellView.Type,
        reuseIdentifier: String = UUID().uuidString,
        configure: @escaping (BaseItemModelType, UITableViewCell, UITableView, IndexPath) -> Void
    ) -> SourcererExtension.TableViewBindingReady<Value, P, E, BaseItemModelType, SectionModelType> {

        let itemViewsProducer = ItemViewsProducer<BaseItemModelType, UITableViewCell, UITableView>
            .tableViewCellWithClass(
                `class`,
                reuseIdentifier: reuseIdentifier,
                configureView: configure
            )

        return SourcererExtension.TableViewBindingReady(
            tableView: tableView, dataSource: dataSource,
            itemModelsProducer: itemModelsProducer,
            itemViewsProducer: itemViewsProducer
        )
    }

    func multiCellsWithClass<CellView: UITableViewCell>(
        _ `class`: CellView.Type,
        reuseIdentifier: String = UUID().uuidString,
        configure: @escaping (BaseItemModelType, UITableViewCell, UITableView, IndexPath) -> Void
        ) -> SourcererExtension.TableViewBindingReady<Value, P, E, BaseItemModelType, SectionModelType> {

        let itemViewsProducer = ItemViewsProducer<BaseItemModelType, UITableViewCell, UITableView>
            .tableViewCellWithClass(
                `class`,
                reuseIdentifier: reuseIdentifier,
                configureView: configure
            )

        return SourcererExtension.TableViewBindingReady(
            tableView: tableView, dataSource: dataSource,
            itemModelsProducer: itemModelsProducer,
            itemViewsProducer: itemViewsProducer
        )
    }
}

public extension SourcererExtension.TableViewBindingReady {

    typealias TableViewCellProducerAlias =
        TableViewCellProducer<IdiomaticItemModel<ItemModelType>>

    func showLoadingAndErrors(
        configuration: ShowLoadingAndErrorsConfiguration,
        loadingViewProducer: TableViewCellProducerAlias,
        errorViewProducer: TableViewCellProducerAlias,
        noResultsViewProducer: TableViewCellProducerAlias
    ) -> SourcererExtension.TableViewBindingReady
        <Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType> {

        let itemViewsProducer = self.itemViewsProducer.showLoadingAndErrorStates(
            configuration: configuration,
            loadingViewProducer: loadingViewProducer,
            errorViewProducer: errorViewProducer,
            noResultsViewProducer: noResultsViewProducer
        )

        let itemModelsProducer = self.itemModelsProducer.showLoadingAndErrorStates(
            configuration: configuration
        )

        return SourcererExtension.TableViewBindingReady(
            tableView: tableView,
            dataSource: dataSource,
            itemModelsProducer: itemModelsProducer,
            itemViewsProducer: itemViewsProducer
        )
    }

}

/// Conforming classes can be bound to a UITableView, therefore
/// remaining retained until the binding is unbound.
public protocol TableViewUnbindable: AnyObject {
    func unbind(from tableView: UITableView)
}

private var tableViewUnbinderAssociativeKey = "TableViewUnbinderAssociativeKey"

private extension UITableView {

    /// With this unbindable, objects bound to the UITableView can be
    /// unbound, effectively releasing and perhaps deallocating them.
    var unbindable: TableViewUnbindable? {
        get {
            return objc_getAssociatedObject(self, &tableViewUnbinderAssociativeKey) as? TableViewUnbindable
        }
        set {
            objc_setAssociatedObject(
                self,
                &tableViewUnbinderAssociativeKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}
