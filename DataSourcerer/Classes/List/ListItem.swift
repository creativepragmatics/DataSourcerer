import Foundation

public protocol ListItem: Equatable {
    associatedtype E: StateError

    // Required to display configuration or system errors
    // for easier debugging.
    init(error: E)
}

public protocol IdiomaticStateError: StateError {
    init(message: StateErrorMessage)
}

public enum IdiomaticListItem<BaseItem: ListItem> : ListItem {
    case baseItem(BaseItem)
    case loading
    case error(BaseItem.E)
    case noResults(String)

    public init(error: BaseItem.E) {
        self = .error(error)
    }
}

public protocol HashableListItem : ListItem, Hashable { }

// MARK: SingleSectionListItems

public enum SingleSectionListItems<LI: ListItem>: Equatable {
    case notReady
    case readyToDisplay([LI])

    public var items: [LI]? {
        switch self {
        case .notReady: return nil
        case let .readyToDisplay(items): return items
        }
    }

    init(sections: ListSections<LI, NoSection>) {
        switch sections {
        case .notReady:
            self = .notReady
        case let .readyToDisplay(sectionsWithItems):
            self = .readyToDisplay(sectionsWithItems.first?.items ?? [])
        }
    }
}

public struct SectionWithItems<Item: ListItem, Section: ListSection>: Equatable {
    public let section: Section
    public let items: [Item]

    public init(_ section: Section, _ items: [Item]) {
        self.section = section
        self.items = items
    }
}

public enum ListSections<Item: ListItem, Section: ListSection>: Equatable {
    public typealias SectionWithItemsConcrete = SectionWithItems<Item, Section>

    case notReady
    case readyToDisplay([SectionWithItemsConcrete])

    public var sectionsWithItems: [SectionWithItems<Item, Section>]? {
        switch self {
        case .notReady: return nil
        case let .readyToDisplay(sectionsWithItems): return sectionsWithItems
        }
    }
}
