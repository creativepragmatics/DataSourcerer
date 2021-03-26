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

extension EnhancedItemModel: MultiViewTypeItemModel where BaseItem: MultiViewTypeItemModel {
    public enum EnhancedItemViewType: CaseIterable, Hashable {
        case enhancementItem
        case baseItem(BaseItem.ItemViewType)

        public static var allCases: [EnhancedItemModel<BaseItem>.EnhancedItemViewType] {
            return [.enhancementItem] + BaseItem.ItemViewType.allCases.map(EnhancedItemViewType.baseItem)
        }
    }

    public var itemViewType: EnhancedItemViewType {
        switch self {
        case .error, .loading, .noResults:
            return .enhancementItem
        case let .baseItem(baseItem):
            return .baseItem(baseItem.itemViewType)
        }
    }
}