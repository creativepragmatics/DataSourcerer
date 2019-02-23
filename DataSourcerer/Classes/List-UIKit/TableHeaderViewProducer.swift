import Foundation
import UIKit

public protocol TableHeaderViewProducer : SupplementaryViewProducer
where ProducedView == UIView, ContainingView == UITableView {}

public struct SimpleTableHeaderViewProducer<Item_: SupplementaryItem>: TableHeaderViewProducer {
    public typealias Item = Item_
    public typealias ProducedView = UIView
    public typealias ContainingView = UITableView

    public typealias UICollectionViewDequeueIdentifier = String

    private let instantiate: (Item, IndexPath) -> UIView

    public func view(containingView: UITableView, item: Item, for indexPath: IndexPath)
        -> ProducedView {
            return instantiate(item, indexPath)
    }

    public func register(at containingView: UITableView) { }

    public var defaultView: ProducedView { return UIView() }
}
