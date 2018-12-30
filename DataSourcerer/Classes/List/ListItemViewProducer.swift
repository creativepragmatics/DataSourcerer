import Foundation

public protocol ListItemViewProducer {
    associatedtype Item: ListItem
    associatedtype ProducedView: UIView
    associatedtype ContainingView: UIView
    func register(itemViewType: Item.ViewType, at containingView: ContainingView)
    func view(containingView: ContainingView, item: Item, for indexPath: IndexPath) -> ProducedView

    var defaultView: ProducedView { get }
}

public extension ListItemViewProducer {
    var any: AnyListItemViewProducer<Item, ProducedView, ContainingView> {
        return AnyListItemViewProducer(self)
    }
}

public struct AnyListItemViewProducer
<Item_: ListItem, ProducedView_: UIView, ContainingView_: UIView> : ListItemViewProducer {

    public typealias Item = Item_
    public typealias ProducedView = ProducedView_
    public typealias ContainingView = ContainingView_

    private let _view: (ContainingView, Item, IndexPath) -> ProducedView
    private let _register: (Item.ViewType, ContainingView) -> Void

    public let defaultView: ProducedView

    public init<P: ListItemViewProducer>(_ producer: P) where P.Item == Item,
        P.ProducedView == ProducedView, P.ContainingView == ContainingView {
        self._view = producer.view
        self._register = producer.register
        self.defaultView = producer.defaultView
    }

    public func view(containingView: ContainingView, item: Item, for indexPath: IndexPath) -> ProducedView {
        return _view(containingView, item, indexPath)
    }

    public func register(itemViewType: Item_.ViewType, at containingView: ContainingView_) {
        _register(itemViewType, containingView)
    }
}
