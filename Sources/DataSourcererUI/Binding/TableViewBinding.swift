import DataSourcerer
import DifferenceKit
import Foundation
import ReactiveSwift
import UIKit

public extension Resource {
    struct TableViewScope {
        let datasource: Resource.Datasource

        public var singleSection: SingleSectionScope {
            .init(tableViewScope: self)
        }

        public var multiSection: MultiSectionScope {
            .init(tableViewScope: self)
        }
    }
}

public extension Resource.TableViewScope {
    indirect enum TableViewCellMaker<ItemModelType: ItemModel, SectionModelType: SectionModel>
    where ItemModelType.Failure == Failure {
        public typealias Configure = (
            ItemModelType, UITableViewCell, UITableView, IndexPath
        ) -> Void

        case `dynamic`(Property<Self>)
        case nonReusable(
                _ make: (ItemModelType, UITableView, IndexPath)
                    -> UITableViewCell,
                configure: Configure = { _, _, _, _ in }
             )
        case reusable(
                _ clazz: UITableViewCell.Type,
                reuseIdentifier: String = UUID().uuidString,
                configure: Configure = { _, _, _, _ in }
             )
        case nib(
                _ nib: UINib,
                reuseIdentifier: String = UUID().uuidString,
                configure: Configure = { _, _, _, _ in }
             )

        public var itemMaker: Property<
            Resource.ListBinding<
                ItemModelType,
                SectionModelType,
                UITableViewCell,
                UITableView
            >.UIViewItemMaker
        > {
            switch self {
            case let .nonReusable(make, configure):
                return Property(
                    value: .tableViewCellWithoutReuse(create: make, configureView: configure)
                )
            case let .reusable(clazz, reuseIdentifier, configure):
                return Property(
                    value: .tableViewCellWithClass(
                        clazz,
                        reuseIdentifier: reuseIdentifier,
                        configureView: configure
                    )
                )
            case let .nib(nib, reuseIdentifier, configure):
                return Property(
                    value: .tableViewCellWithNib(
                        nib,
                        reuseIdentifier: reuseIdentifier,
                        configureView: configure
                    )
                )
            case let .dynamic(property):
                return property.flatMap(.latest) { $0.itemMaker }
            }
        }
    }
}

public extension Resource.Datasource {
    var tableView: Resource.TableViewScope {
        .init(datasource: self)
    }
}

public extension Resource.TableViewScope {
    typealias Binding<ItemModelType: ItemModel, SectionModelType: SectionModel> =
        Resource.ListBinding<
            ItemModelType,
            SectionModelType,
            UITableViewCell,
            UITableView
        > where Resource.FailureType == ItemModelType.Failure

    /// Creates a binding for a single base cell view type.
    func makeBinding<ItemModelType: ItemModel, SectionModelType: SectionModel>(
        cellModelMaker: Property<Binding<ItemModelType, SectionModelType>.ListViewStateMaker>,
        cellViewMaker: Property<Binding<ItemModelType, SectionModelType>.UIViewItemMaker>,
        sectionHeaderMaker: Property<TableViewSupplementaryViewMaker<ItemModelType, SectionModelType>>,
        sectionFooterMaker: Property<TableViewSupplementaryViewMaker<ItemModelType, SectionModelType>>
    ) -> Resource.ListBinding<ItemModelType, SectionModelType, UITableViewCell, UITableView> {
        typealias Binding = Resource.ListBinding<
            ItemModelType,
            SectionModelType,
            UITableViewCell,
            UITableView
        >
        typealias TableViewSupplementaryViewMakerType =
            TableViewSupplementaryViewMaker<ItemModelType, SectionModelType>

        let supplementaryViewMaker = sectionHeaderMaker
            .combineLatest(with: sectionFooterMaker)
            .map(TableViewSupplementaryViewMakerType.combine(sectionHeader:sectionFooter:))

        return .init(
            datasource: datasource,
            listViewStateMaker: cellModelMaker,
            itemViewMaker: cellViewMaker,
            supplementaryViewMaker: supplementaryViewMaker
        )
    }

    /// Creates a binding for multiple base cell view types.
    func makeBinding<ItemModelType: MultiViewTypeItemModel, SectionModelType: SectionModel>(
        cellModelMaker: Property<Binding<ItemModelType, SectionModelType>.ListViewStateMaker>,
        multiCellViewMaker: (ItemModelType.ItemViewType)
            -> Property<Binding<ItemModelType, SectionModelType>.UIViewItemMaker>,
        sectionHeaderMaker: Property<TableViewSupplementaryViewMaker<ItemModelType, SectionModelType>>,
        sectionFooterMaker: Property<TableViewSupplementaryViewMaker<ItemModelType, SectionModelType>>
    ) -> Resource.ListBinding<ItemModelType, SectionModelType, UITableViewCell, UITableView> {
        typealias Binding = Resource.ListBinding<
            ItemModelType,
            SectionModelType,
            UITableViewCell,
            UITableView
        >

        let allCellMakers: [Property<(Binding.UIViewItemMaker, ItemModelType.ItemViewType)>] =
            ItemModelType.ItemViewType.allCases.map { type in
                multiCellViewMaker(type).map { ($0, type) }
            }

        let combinedCellViewMaker = Property<Binding.UIViewItemMaker>
            .combineLatest(allCellMakers, emptySentinel: [])
            .map { itemMakers -> Binding.UIViewItemMaker in

                let getItemMaker = { (type: ItemModelType.ItemViewType) -> Binding.UIViewItemMaker in
                    itemMakers.first(where: { $0.1 == type })!.0
                }

                return Binding.UIViewItemMaker(
                    makeView: { item, tableView, indexPath in
                        getItemMaker(item.itemViewType).makeView(item, tableView, indexPath)
                    },
                    configureView: { item, itemView, tableView, indexPath in
                        getItemMaker(item.itemViewType)
                            .configureView(item, itemView, tableView, indexPath)
                    },
                    registerAtContainerView: { tableView in
                        itemMakers.forEach { $0.0.registerAtContainerView(tableView) }
                    }
                )
            }

        return makeBinding(
            cellModelMaker: cellModelMaker,
            cellViewMaker: combinedCellViewMaker,
            sectionHeaderMaker: sectionHeaderMaker,
            sectionFooterMaker: sectionFooterMaker
        )
    }

    enum TableViewSupplementaryViewMaker<ItemModelType: ItemModel, SectionModelType: SectionModel>
    where Resource.FailureType == ItemModelType.Failure {
        public typealias MakeSupplementaryViewMaker =
            (SectionModelType, IndexPath, UITableView) ->
            Binding<ItemModelType, SectionModelType>.SupplementaryView

        case none
        case make(MakeSupplementaryViewMaker)

        static func combine(sectionHeader: Self, sectionFooter: Self)
        -> Binding<ItemModelType, SectionModelType>.SupplementaryViewMaker {
            return .init { params -> Binding<ItemModelType, SectionModelType>.SupplementaryView in
                switch params.kind {
                case let .sectionHeader(sectionModel):
                    switch sectionHeader {
                    case .none:
                        return .none
                    case let .make(makeView):
                        return makeView(sectionModel, params.indexPath, params.containingView)
                    }
                case let .sectionFooter(sectionModel):
                    switch sectionFooter {
                    case .none:
                        return .none
                    case let .make(makeView):
                        return makeView(sectionModel, params.indexPath, params.containingView)
                    }
                case .item:
                    return .none
                }
            }
        }
    }
}
