import Foundation

/// A supplementary item is the pendant of a section header
/// of UITableView, or a supplementary view of UICollectionView.
public protocol SupplementaryItemModel: ItemModel {

    // Required to display configuration or system errors
    // for easier debugging.
    init(error: E)

    var type: SupplementaryItemModelType { get }
}

public enum SupplementaryItemModelType {
    case `default`
    case header
    case footer
}

public struct NoSupplementaryItemModel: SupplementaryItemModel {
    public typealias E = NoResourceError
    
    public let differenceIdentifier: String = "noSupplementaryItemModel"
    public var type: SupplementaryItemModelType {
        return .default
    }

    public init(error: E) {}

    public func isContentEqual(to source: NoSupplementaryItemModel) -> Bool {
        return source.differenceIdentifier == self.differenceIdentifier
    }
}
