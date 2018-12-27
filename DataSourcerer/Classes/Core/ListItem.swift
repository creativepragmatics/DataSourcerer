import Foundation
import UIKit

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

public protocol DefaultListItem : ListItem {
    associatedtype DatasourceItem: Any
    associatedtype E: DatasourceError

    static var loadingCell: Self { get }
    static var noResultsCell: Self { get }

    static func errorCell(_ error: E) -> Self

    init(datasourceItem: DatasourceItem)
}

public protocol HashableListItem : ListItem, Hashable { }

// MARK: List Item View Producer

public protocol ListItemViewProducer {
    associatedtype Item: ListItem
    associatedtype ProducedView: UIView
    associatedtype ContainingView: UIView
    func register(itemViewType: Item.ViewType, at containingView: ContainingView)
    func view(containingView: ContainingView, item: Item, for indexPath: IndexPath) -> ProducedView

    var defaultView: ProducedView { get }
}

public extension ListItemViewProducer {
    var any: AnyListItemViewProducer<Item, ProducedView, ContainingView> {
        return AnyListItemViewProducer(self)
    }
}

public struct AnyListItemViewProducer
<Item_: ListItem, ProducedView_: UIView, ContainingView_: UIView> : ListItemViewProducer {

    public typealias Item = Item_
    public typealias ProducedView = ProducedView_
    public typealias ContainingView = ContainingView_

    private let _view: (ContainingView, Item, IndexPath) -> ProducedView
    private let _register: (Item.ViewType, ContainingView) -> Void

    public let defaultView: ProducedView

    public init<P: ListItemViewProducer>(_ producer: P) where P.Item == Item,
        P.ProducedView == ProducedView, P.ContainingView == ContainingView {
        self._view = producer.view
        self._register = producer.register
        self.defaultView = producer.defaultView
    }

    public func view(containingView: ContainingView, item: Item, for indexPath: IndexPath) -> ProducedView {
        return _view(containingView, item, indexPath)
    }

    public func register(itemViewType: Item_.ViewType, at containingView: ContainingView_) {
        _register(itemViewType, containingView)
    }
}

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
