import Foundation
import UIKit

public protocol TableViewCellProducer : ListItemViewProducer
where ProducedView == UITableViewCell, ContainingView == UITableView {}

public enum SimpleTableViewCellProducer<Cell: ListItem>: TableViewCellProducer {
    public typealias Item = Cell
    public typealias ProducedView = UITableViewCell
    public typealias ContainingView = UITableView
    public typealias TableViewCellDequeueIdentifier = String

    // Cell class registration is performed automatically:
    case classAndIdentifier(class: UITableViewCell.Type,
        identifier: TableViewCellDequeueIdentifier,
        configure: (Cell, UITableViewCell) -> Void)

    case nibAndIdentifier(nib: UINib,
        identifier: TableViewCellDequeueIdentifier,
        configure: (Cell, UITableViewCell) -> Void)

    // No cell class registration is performed:
    case instantiate((Cell) -> UITableViewCell)

    public func view(containingView: UITableView, item: Cell, for indexPath: IndexPath) -> ProducedView {
        switch self {
        case let .classAndIdentifier(_, identifier, configure):
            let tableViewCell = containingView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
            configure(item, tableViewCell)
            return tableViewCell
        case let .nibAndIdentifier(_, identifier, configure):
            let tableViewCell = containingView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
            configure(item, tableViewCell)
            return tableViewCell
        case let .instantiate(instantiate):
            return instantiate(item)
        }
    }

    public func register(itemViewType: Cell.ViewType, at containingView: UITableView) {
        switch self {
        case let .classAndIdentifier(clazz, identifier, _):
            containingView.register(clazz, forCellReuseIdentifier: identifier)
        case let .nibAndIdentifier(nib, identifier, _):
            containingView.register(nib, forCellReuseIdentifier: identifier)
        case .instantiate:
            break
        }
    }

    public var defaultView: UITableViewCell { return UITableViewCell() }
}
