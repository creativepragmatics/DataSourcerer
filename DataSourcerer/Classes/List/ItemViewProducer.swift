import Foundation

public protocol ItemViewProducer {
    associatedtype ItemModelType: Equatable
    associatedtype ProducedView: UIView
    associatedtype ContainingView: UIView
    func register(at containingView: ContainingView)
    func view(containingView: ContainingView, item: ItemModelType, for indexPath: IndexPath) -> ProducedView

    var defaultView: ProducedView { get }
}

public extension ItemViewProducer {
    var any: AnyItemViewProducer<ItemModelType, ProducedView, ContainingView> {
        return AnyItemViewProducer(self)
    }
}

public struct AnyItemViewProducer
<ItemModelType_: Equatable, ProducedView_: UIView, ContainingView_: UIView> : ItemViewProducer {

    public typealias ItemModelType = ItemModelType_
    public typealias ProducedView = ProducedView_
    public typealias ContainingView = ContainingView_

    private let _view: (ContainingView, ItemModelType, IndexPath) -> ProducedView
    private let _register: (ContainingView) -> Void

    public let defaultView: ProducedView

    public init<P: ItemViewProducer>(_ producer: P) where P.ItemModelType == ItemModelType,
        P.ProducedView == ProducedView, P.ContainingView == ContainingView {
        self._view = producer.view
        self._register = producer.register
        self.defaultView = producer.defaultView
    }

    public func view(containingView: ContainingView, item: ItemModelType, for indexPath: IndexPath)
        -> ProducedView {

        return _view(containingView, item, indexPath)
    }

    public func register(at containingView: ContainingView_) {
        _register(containingView)
    }
}
