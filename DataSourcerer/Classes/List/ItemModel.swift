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

public enum SingleSectionListViewState<Value, P: ResourceParams, E: ResourceError, LI: ItemModel>:
Equatable {

    case notReady
    case readyToDisplay(ResourceState<Value, P, E>, [LI])

    public var items: [LI]? {
        switch self {
        case .notReady: return nil
        case let .readyToDisplay(_, items): return items
        }
    }

    init(listViewState: ListViewState<Value, P, E, LI, NoSection>) {
        switch listViewState {
        case .notReady:
            self = .notReady
        case let .readyToDisplay(resourceState, sectionsWithItems):
            self = .readyToDisplay(
                resourceState,
                sectionsWithItems.first?.items ?? []
            )
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

public enum ListViewState
    <Value, P: ResourceParams, E: ResourceError, ItemModelType: ItemModel,
    SectionModelType: SectionModel>: Equatable {

    case notReady
    case readyToDisplay(
        ResourceState<Value, P, E>,
        [SectionAndItems<ItemModelType, SectionModelType>]
    )

    public var sectionsWithItems: [SectionAndItems<ItemModelType, SectionModelType>]? {
        switch self {
        case .notReady: return nil
        case let .readyToDisplay(_, sectionsWithItems): return sectionsWithItems
        }
    }
}

public extension ListViewState {

    func doCellsDiffer(other: ListViewState) -> Bool {
        switch (self, other) {
        case (.notReady, .notReady):
            return false
        case (.notReady, .readyToDisplay), (.readyToDisplay, .notReady):
            return true
        case let (.readyToDisplay(_, lhsSectionsAndItems),
                  .readyToDisplay(_, rhsSectionsAndItems)):
            return lhsSectionsAndItems == rhsSectionsAndItems
        }
    }
}

public extension SingleSectionListViewState {

    func doCellsDiffer(other: SingleSectionListViewState) -> Bool {
        switch (self, other) {
        case (.notReady, .notReady):
            return false
        case (.notReady, .readyToDisplay), (.readyToDisplay, .notReady):
            return true
        case let (.readyToDisplay(_, lhsSectionsAndItems),
                  .readyToDisplay(_, rhsSectionsAndItems)):
            return lhsSectionsAndItems == rhsSectionsAndItems
        }
    }
}
