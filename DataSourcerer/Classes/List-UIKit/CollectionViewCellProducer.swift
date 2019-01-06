import Foundation
import UIKit

public protocol CollectionViewCellProducer : ListItemViewProducer
where ProducedView == UICollectionViewCell, ContainingView == UICollectionView {}

public enum SimpleCollectionViewCellProducer<Cell: ListItem>: CollectionViewCellProducer {
    public typealias Item = Cell
    public typealias ProducedView = UICollectionViewCell
    public typealias ContainingView = UICollectionView

    public typealias UICollectionViewDequeueIdentifier = String

    // Cell class registration is performed automatically:
    case classAndIdentifier(
        class: UICollectionViewCell.Type,
        identifier: UICollectionViewDequeueIdentifier,
        configure: (IndexPath, Cell, UICollectionViewCell) -> Void
    )

    case nibAndIdentifier(
        nib: UINib,
        identifier: UICollectionViewDequeueIdentifier,
        configure: (IndexPath, Cell, UICollectionViewCell) -> Void
    )

    public func view(containingView: UICollectionView, item: Cell, for indexPath: IndexPath)
        -> ProducedView {
        switch self {
        case let .classAndIdentifier(_, identifier, configure):
            let collectionViewCell = containingView.dequeueReusableCell(withReuseIdentifier: identifier,
                                                                        for: indexPath)
            configure(indexPath, item, collectionViewCell)
            return collectionViewCell
        case let .nibAndIdentifier(_, identifier, configure):
            let collectionViewCell = containingView.dequeueReusableCell(withReuseIdentifier: identifier,
                                                                        for: indexPath)
            configure(indexPath, item, collectionViewCell)
            return collectionViewCell
        }
    }

    public func register(itemViewType: Cell.ViewType, at containingView: UICollectionView) {
        switch self {
        case let .classAndIdentifier(clazz, identifier, _):
            containingView.register(clazz, forCellWithReuseIdentifier: identifier)
        case let .nibAndIdentifier(nib, identifier, _):
            containingView.register(nib, forCellWithReuseIdentifier: identifier)
        }
    }

    // Will cause a crash if used:
    public var defaultView: UICollectionViewCell { return UICollectionViewCell() }
}
