import Foundation

/// A supplementary item is the pendant of a section header
/// of UITableView, or a supplementary view of UICollectionView.
public protocol SupplementaryItem: Equatable {
    associatedtype E: StateError

    // Required to display configuration or system errors
    // for easier debugging.
    init(error: E)

    var type: SupplementaryItemType { get }
}

public enum SupplementaryItemType {
    case `default`
    case header
    case footer
}

public struct NoSupplementaryItem: SupplementaryItem {
    public typealias E = NoStateError

    public init(error: E) {}

    public var type: SupplementaryItemType {
        return .default
    }
}
