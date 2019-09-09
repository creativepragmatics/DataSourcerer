import Foundation
import UIKit

public struct ItemViewsProducer<ItemModelType: ItemModel, ProducedView: UIView, ContainingView: UIView> {

    public let produceView: (ItemModelType, ContainingView, IndexPath) -> ProducedView
    public let configureView: (ItemModelType, ProducedView, ContainingView, IndexPath) -> Void
    public let registerAtContainingView: (ContainingView) -> Void
    public let itemViewSize: ((ItemModelType, ContainingView, IndexPath) -> CGSize?)?

    public init(
        produceView: @escaping (ItemModelType, ContainingView, IndexPath) -> ProducedView,
        configureView: @escaping (ItemModelType, ProducedView, ContainingView, IndexPath) -> Void,
        registerAtContainingView: @escaping (ContainingView) -> Void,
        itemViewSize: ((ItemModelType, ContainingView, IndexPath) -> CGSize)? = nil
    ) {
        self.produceView = produceView
        self.configureView = configureView
        self.registerAtContainingView = registerAtContainingView
        self.itemViewSize = itemViewSize
    }

    public func produceAndConfigureView(
        itemModel: ItemModelType,
        containingView: ContainingView,
        indexPath: IndexPath
    ) -> ProducedView {
        let view = produceView(itemModel, containingView, indexPath)
        configureView(itemModel, view, containingView, indexPath)
        return view
    }
}

public protocol MultiViewTypeItemModel: ItemModel {
    associatedtype ItemViewType: CaseIterable, Hashable

    var itemViewType: ItemViewType { get }
}

public extension ItemViewsProducer where ItemModelType: MultiViewTypeItemModel {

    init(
        multiViewTypeWithProducer createProducers: @escaping (ItemModelType.ItemViewType) -> ItemViewsProducer,
        itemViewSize: ((ItemModelType, ContainingView, IndexPath) -> CGSize)? = nil
    ) {

        var viewProducersCache: [ItemModelType.ItemViewType: ItemViewsProducer] = [:]
        func cachedProducer(_ viewType: ItemModelType.ItemViewType) -> ItemViewsProducer {
            if let producer = viewProducersCache[viewType] {
                return producer
            } else {
                let producer = createProducers(viewType)
                viewProducersCache[viewType] = producer
                return producer
            }
        }

        self.produceView = { itemModel, containingView, indexPath -> ProducedView in
            return cachedProducer(itemModel.itemViewType)
                .produceView(itemModel, containingView, indexPath)
        }

        self.configureView = { itemModel, producedView, containingView, indexPath in
            cachedProducer(itemModel.itemViewType)
                .configureView(itemModel, producedView, containingView, indexPath)
        }

        self.registerAtContainingView = { containingView in
            ItemModelType.ItemViewType.allCases.forEach {
                let viewProducer = cachedProducer($0)
                viewProducer.registerAtContainingView(containingView)
            }
        }

        self.itemViewSize = { itemModel, containingView, indexPath -> CGSize? in
            return cachedProducer(itemModel.itemViewType)
                .itemViewSize?(itemModel, containingView, indexPath)
        }
    }
}

public extension ItemViewsProducer {

//    init<ViewProducer: ItemViewProducer>(forSingleViewTypeWithProducer viewProducer: ViewProducer)
//        where ViewProducer.ItemModelType == ItemModelType, ViewProducer.ContainingView == ContainingView,
//        ViewProducer.ProducedView == ProducedView {
//
//        self.init(
//            produceView: { item, containingView, indexPath -> ProducedView in
//                return viewProducer.view(containingView: containingView, item: item, for: indexPath)
//            },
//            registerAtContainingView: { containingView in
//                viewProducer.register(at: containingView)
//            }
//        )
//    }

}

extension ItemViewsProducer where ItemModelType == NoSupplementaryItemModel {

    static var noSupplementaryItemViewsProducer: ItemViewsProducer
        <NoSupplementaryItemModel, UIView, ContainingView> {

            return ItemViewsProducer<NoSupplementaryItemModel, UIView, ContainingView>(
                produceView: { _, _, _ in UIView() },
                configureView: { _, _, _, _ in return },
                registerAtContainingView: { _ in }
            )
    }
}

public typealias TableViewCellAdapter<Cell: ItemModel>
    = ItemViewsProducer<Cell, UITableViewCell, UITableView>

public extension ItemViewsProducer {

    static func tableViewCellWithClass<Cell: ItemModel, CellView: UITableViewCell>(
        _ `class`: CellView.Type,
        reuseIdentifier: String = UUID().uuidString,
        configureView: @escaping (Cell, UITableViewCell, UITableView, IndexPath) -> Void,
        cellSize: ((Cell, UITableView, IndexPath) -> CGSize)? = nil
    ) -> ItemViewsProducer<Cell, UITableViewCell, UITableView> {

        return ItemViewsProducer<Cell, UITableViewCell, UITableView>(
            produceView: { itemModel, tableView, indexPath -> UITableViewCell in
                return tableView.dequeueReusableCell(
                    withIdentifier: reuseIdentifier,
                    for: indexPath
                )
            },
            configureView: configureView,
            registerAtContainingView: { tableView in
                tableView.register(`class`, forCellReuseIdentifier: reuseIdentifier)
            },
            itemViewSize: cellSize
        )
    }

    static func tableViewCellWithNib<Cell: ItemModel>(
        _ nib: UINib,
        reuseIdentifier: String = UUID().uuidString,
        configureView: @escaping (Cell, UITableViewCell, UITableView, IndexPath) -> Void,
        cellSize: ((Cell, UITableView, IndexPath) -> CGSize)? = nil
    ) -> ItemViewsProducer<Cell, UITableViewCell, UITableView> {

        return ItemViewsProducer<Cell, UITableViewCell, UITableView>(
            produceView: { itemModel, tableView, indexPath -> UITableViewCell in
                let tableViewCell = tableView.dequeueReusableCell(
                    withIdentifier: reuseIdentifier,
                    for: indexPath
                )
                return tableViewCell
            },
            configureView: configureView,
            registerAtContainingView: { tableView in
                tableView.register(nib, forCellReuseIdentifier: reuseIdentifier)
            },
            itemViewSize: cellSize
        )
    }

    static func tableViewCellWithoutReuse<Cell: ItemModel>(
        create: @escaping (Cell, UITableView, IndexPath) -> UITableViewCell,
        configureView: @escaping (Cell, UITableViewCell, UITableView, IndexPath) -> Void = { _, _, _, _ in },
        cellSize: ((Cell, UITableView, IndexPath) -> CGSize)? = nil
    ) -> ItemViewsProducer<Cell, UITableViewCell, UITableView> {

        return ItemViewsProducer<Cell, UITableViewCell, UITableView>(
            produceView: { itemModel, tableView, indexPath -> UITableViewCell in
                return create(itemModel, tableView, indexPath)
            },
            configureView: configureView,
            registerAtContainingView: { _ in },
            itemViewSize: cellSize
        )
    }

}

public typealias TableViewCellProducer<ItemModelType: ItemModel> =
    ItemViewsProducer<ItemModelType, UITableViewCell, UITableView>
