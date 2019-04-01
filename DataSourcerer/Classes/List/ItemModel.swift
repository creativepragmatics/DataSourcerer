import Foundation

public protocol ItemModel: Equatable {
    associatedtype E: ResourceError

    // Required to display configuration or system errors
    // for easier debugging.
    init(error: E)
}

public protocol IdiomaticStateError: ResourceError {
    init(message: StateErrorMessage)
}

public enum IdiomaticItemModel<BaseItem: ItemModel> : ItemModel {
    case baseItem(BaseItem)
    case loading
    case error(BaseItem.E)
    case noResults(String)

    public init(error: BaseItem.E) {
        self = .error(error)
    }
}

public protocol HashableItemModel : ItemModel, Hashable { }

// MARK: SingleSectionListViewState

public enum SingleSectionListViewState<P: ResourceParams, LI: ItemModel>: Equatable {
    case notReady
    case readyToDisplay(LoadImpulse<P>, [LI])

    public var items: [LI]? {
        switch self {
        case .notReady: return nil
        case let .readyToDisplay(_, items): return items
        }
    }

    init(sections: ListViewState<P, LI, NoSection>) {
        switch sections {
        case .notReady:
            self = .notReady
        case let .readyToDisplay(loadImpulse, sectionsWithItems):
            self = .readyToDisplay(loadImpulse, sectionsWithItems.first?.items ?? [])
        }
    }
}

public struct SectionAndItems<Item: ItemModel, Section: SectionModel>: Equatable {
    public let section: Section
    public let items: [Item]

    public init(_ section: Section, _ items: [Item]) {
        self.section = section
        self.items = items
    }
}

public enum ListViewState<P: ResourceParams, ItemModelType: ItemModel, SectionModelType: SectionModel>: Equatable {

    case notReady
    case readyToDisplay(LoadImpulse<P>, [SectionAndItems<ItemModelType, SectionModelType>])

    public var sectionsWithItems: [SectionAndItems<ItemModelType, SectionModelType>]? {
        switch self {
        case .notReady: return nil
        case let .readyToDisplay(_, sectionsWithItems): return sectionsWithItems
        }
    }
}
