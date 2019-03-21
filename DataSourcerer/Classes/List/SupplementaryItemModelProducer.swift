import Foundation

public protocol SupplementaryItemModelProducer {
    associatedtype SupplementaryItemModelType: SupplementaryItemModel
    associatedtype ProducedView: UIView
    associatedtype ContainingView: UIView
    func register(at containingView: ContainingView)
    func view(containingView: ContainingView, item: SupplementaryItemModelType, for indexPath: IndexPath)
        -> ProducedView

    var defaultView: ProducedView { get }
}

public extension SupplementaryItemModelProducer {
    var any: AnySupplementaryItemModelProducer<SupplementaryItemModelType, ProducedView, ContainingView> {
        return AnySupplementaryItemModelProducer(self)
    }
}

public struct AnySupplementaryItemModelProducer
<Item_: SupplementaryItemModel, ProducedView_: UIView, ContainingView_: UIView>
: SupplementaryItemModelProducer {

    public typealias Item = Item_
    public typealias ProducedView = ProducedView_
    public typealias ContainingView = ContainingView_

    private let _view: (ContainingView, Item, IndexPath) -> ProducedView
    private let _register: (ContainingView) -> Void

    public let defaultView: ProducedView

    public init<P: SupplementaryItemModelProducer>(_ producer: P) where P.SupplementaryItemModelType == Item,
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
