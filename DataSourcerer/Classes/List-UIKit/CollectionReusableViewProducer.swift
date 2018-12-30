import Foundation
import UIKit

// Will probably never be needed because datasources should not
// mix data (ListItem) with view attributes (supplementary views).
// Keeping this file for now, just in case.

public protocol CollectionReusableViewProducer : ListItemViewProducer
where ProducedView == UICollectionReusableView, ContainingView == UICollectionView {}

public enum DefaultCollectionReusableViewProducer<ReusableView: ListItem>: CollectionReusableViewProducer {
    public typealias Item = ReusableView
    public typealias ProducedView = UICollectionReusableView
    public typealias ContainingView = UICollectionView

    public typealias UICollectionViewDequeueIdentifier = String

    // Cell class registration is performed automatically:
    case classAndIdentifier(
        class: AnyClass,
        kind: Kind,
        identifier: UICollectionViewDequeueIdentifier,
        configure: (ReusableView, UICollectionReusableView) -> Void
    )

    case nibAndIdentifier(
        nib: UINib,
        kind: Kind,
        identifier: UICollectionViewDequeueIdentifier,
        configure: (ReusableView, UICollectionReusableView) -> Void
    )

    public func view(containingView: UICollectionView, item: ReusableView, for indexPath: IndexPath)
        -> ProducedView {
            switch self {
            case let .classAndIdentifier(_, kind, identifier, configure):
                let supplementaryView = containingView.dequeueReusableSupplementaryView(
                    ofKind: kind.description,
                    withReuseIdentifier: identifier,
                    for: indexPath
                )
                configure(item, supplementaryView)
                return supplementaryView
            case let .nibAndIdentifier(_, kind, identifier, configure):
                let supplementaryView = containingView.dequeueReusableSupplementaryView(
                    ofKind: kind.description,
                    withReuseIdentifier: identifier,
                    for: indexPath
                )
                configure(item, supplementaryView)
                return supplementaryView
            }
    }

    public func register(itemViewType: ReusableView.ViewType, at containingView: UICollectionView) {
        switch self {
        case let .classAndIdentifier(clazz, kind, identifier, _):
            containingView.register(clazz,
                                    forSupplementaryViewOfKind: kind.description,
                                    withReuseIdentifier: identifier)
        case let .nibAndIdentifier(nib, kind, identifier, _):
            containingView.register(nib,
                                    forSupplementaryViewOfKind: kind.description,
                                    withReuseIdentifier: identifier)
        }
    }

    public var defaultView: UICollectionReusableView { return UICollectionReusableView() }

    public enum Kind: CustomStringConvertible {
        case sectionHeader
        case sectionFooter
        case custom(String)

        public var description: String {
            switch self {
            case .sectionHeader: return UICollectionView.elementKindSectionHeader
            case .sectionFooter: return UICollectionView.elementKindSectionFooter
            case let .custom(kind): return kind
            }
        }
    }
}
