import Foundation

public struct ItemViewsProducer<ItemModelType: Equatable, ProducedView: UIView, ContainingView: UIView> {

    public let produceView: (ItemModelType, ContainingView, IndexPath) -> ProducedView
    public let registerAtContainingView: (ContainingView) -> Void
    public let itemViewSize: ((ItemModelType, ContainingView) -> CGSize)?

    public init(
        produceView: @escaping (ItemModelType, ContainingView, IndexPath) -> ProducedView,
        registerAtContainingView: @escaping (ContainingView) -> Void,
        itemViewSize: ((ItemModelType, ContainingView) -> CGSize)? = nil
    ) {
        self.produceView = produceView
        self.registerAtContainingView = registerAtContainingView
        self.itemViewSize = itemViewSize
    }
}

public protocol MultiViewTypeItemModel: ItemModel {
    associatedtype ItemViewType: CaseIterable

    var itemViewType: ItemViewType { get }
}

public extension ItemViewsProducer where ItemModelType: MultiViewTypeItemModel {

    init(
        forMultiViewTypeWithProducer producer: @escaping (ItemModelType.ItemViewType) -> ItemViewsProducer,
        itemViewSize: ((ItemModelType, ContainingView) -> CGSize)? = nil
    ) {

        self.produceView = { itemModel, containingView, indexPath -> ProducedView in
            return producer(itemModel.itemViewType)
                .produceView(itemModel, containingView, indexPath)
        }

        self.registerAtContainingView = { containingView in
            ItemModelType.ItemViewType.allCases.forEach {
                let viewProducer = producer($0)
                viewProducer.registerAtContainingView(containingView)
            }
        }

        self.itemViewSize = itemViewSize
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
                registerAtContainingView: { _ in }
            )
    }
}

public typealias TableViewCellAdapter<Cell: ItemModel>
    = ItemViewsProducer<Cell, UITableViewCell, UITableView>

public extension ItemViewsProducer where ProducedView == UITableViewCell, ContainingView == UITableView {

    static func tableViewCellWithClass<Cell: ItemModel, CellView: UITableViewCell>(
        _ `class`: CellView.Type,
        reuseIdentifier: String = UUID().uuidString,
        configure: @escaping (Cell, UITableViewCell) -> Void
    ) -> ItemViewsProducer<Cell, UITableViewCell, UITableView> {

        return ItemViewsProducer<Cell, UITableViewCell, UITableView>(
            produceView: { itemModel, tableView, indexPath -> UITableViewCell in
                let tableViewCell = tableView.dequeueReusableCell(
                    withIdentifier: reuseIdentifier,
                    for: indexPath
                )
                configure(itemModel, tableViewCell)
                return tableViewCell
            },
            registerAtContainingView: { tableView in
                tableView.register(`class`, forCellReuseIdentifier: reuseIdentifier)
            }
        )
    }

    static func tableViewCellWithNib<Cell: ItemModel>(
        _ nib: UINib,
        reuseIdentifier: String = UUID().uuidString,
        configure: @escaping (Cell, UITableViewCell) -> Void
    ) -> ItemViewsProducer<Cell, UITableViewCell, UITableView> {

        return ItemViewsProducer<Cell, UITableViewCell, UITableView>(
            produceView: { itemModel, tableView, indexPath -> UITableViewCell in
                let tableViewCell = tableView.dequeueReusableCell(
                    withIdentifier: reuseIdentifier,
                    for: indexPath
                )
                configure(itemModel, tableViewCell)
                return tableViewCell
            },
            registerAtContainingView: { tableView in
                tableView.register(nib, forCellReuseIdentifier: reuseIdentifier)
            }
        )
    }

}
