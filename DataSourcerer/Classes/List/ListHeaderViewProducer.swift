import Foundation

public protocol SupplementaryViewProducer {
    associatedtype Item: SupplementaryItem
    associatedtype ProducedView: UIView
    associatedtype ContainingView: UIView
    func register(at containingView: ContainingView)
    func view(containingView: ContainingView, item: Item, for indexPath: IndexPath) -> ProducedView

    var defaultView: ProducedView { get }
}

public extension SupplementaryViewProducer {
    var any: AnySupplementaryViewProducer<Item, ProducedView, ContainingView> {
        return AnySupplementaryViewProducer(self)
    }
}

public struct AnySupplementaryViewProducer
<Item_: SupplementaryItem, ProducedView_: UIView, ContainingView_: UIView> : SupplementaryViewProducer {

    public typealias Item = Item_
    public typealias ProducedView = ProducedView_
    public typealias ContainingView = ContainingView_

    private let _view: (ContainingView, Item, IndexPath) -> ProducedView
    private let _register: (ContainingView) -> Void

    public let defaultView: ProducedView

    public init<P: SupplementaryViewProducer>(_ producer: P) where P.Item == Item,
        P.ProducedView == ProducedView, P.ContainingView == ContainingView {
            self._view = producer.view
            self._register = producer.register
            self.defaultView = producer.defaultView
    }

    public func view(containingView: ContainingView, item: Item, for indexPath: IndexPath) -> ProducedView {
        return _view(containingView, item, indexPath)
    }

    public func register(at containingView: ContainingView_) {
        _register(containingView)
    }
}
