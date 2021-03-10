import DifferenceKit
import Foundation

public enum EnhancedItemModel<BaseItem: ItemModel>: ItemModel {
    case baseItem(BaseItem)
    case loading
    case error(BaseItem.Failure)
    case noResults

    public init(error: BaseItem.Failure) {
        self = .error(error)
    }

    /// An identifier value for difference calculation.
    public var differenceIdentifier: String {
        switch self {
        case let .baseItem(item):
            return item.differenceIdentifier
        case let .error(error):
            return "__error__\(error.differenceIdentifier)"
        case .loading:
            return "__loading__"
        case .noResults:
            return "__noresults__"
        }
    }

    public func isContentEqual(to source: EnhancedItemModel<BaseItem>) -> Bool {
        switch (self, source) {
        case let (.baseItem(lhs), .baseItem(rhs)):
            return lhs.isContentEqual(to: rhs)
        case let (.error(lhs), .error(rhs)):
            return lhs.isContentEqual(to: rhs)
        case (.loading, .loading):
            return true
        case (.noResults, .noResults):
            return true
        default:
            return false
        }
    }
}
