import Foundation

public protocol ListItem: Equatable {
    associatedtype ViewType: ListItemViewType

    var viewType: ViewType { get }

    // Required to display configuration or system errors
    // for easier debugging.
    init(errorMessage: String)
}

public protocol ListItemViewType: CaseIterable, Hashable {
    var isSelectable: Bool { get }
}

public protocol IdiomaticListItem : ListItem {
    associatedtype DatasourceItem: Any
    associatedtype E: StateError

    static var loadingCell: Self { get }
    static var noResultsCell: Self { get }

    static func errorCell(_ error: E) -> Self

    init(datasourceItem: DatasourceItem)
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
