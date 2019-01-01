import Foundation
import UIKit

/// Default implementation for a single section tableview
/// with support for loading indicator, "no results" cell
/// and error cell.
/// Configuration has to be done before the `cells`
/// property is accessed.
open class DefaultSingleSectionTableViewDatasource
    <Value, P: Parameters, E, Cell: DefaultListItem>:
    NSObject, UITableViewDelegate, UITableViewDataSource where Cell.E == E {
    public typealias CellViewProducer = DefaultTableViewCellProducer<Cell>
    public typealias SourceDatasource = AnyDatasource<State<Value, P, E>>
    public typealias Core = DefaultSingleSectionListViewDatasourceCore
        <Value, P, E, CellViewProducer>

    public var core: Core

    private let sourceDatasource: SourceDatasource

    /// If true, use heightAtIndexPath to store item heights. Most likely
    /// only makes sense in TableViews with autolayouted cells.
    public var useFixedItemHeights = false
    public var heightAtIndexPath: [IndexPath: CGFloat] = [:]
    private var isConfigured = false

    public lazy var cells: AnyDatasource<Core.Items> = {
        assert(isConfigured, """
                             Configure DefaultSingleSectionTableViewDatasource before
                             accessing the cells property.
                             """)

        return self.sourceDatasource
            .map(self.core.stateToItems)
            .observeOnUIThread()
            .any
    }()

    public init(sourceDatasource: SourceDatasource,
                cellType: Cell.Type? = nil) {
        self.sourceDatasource = sourceDatasource
        self.core =
            DefaultSingleSectionListViewDatasourceCore()
    }

    public func configure(_ build: (Core.Builder) -> (Core.Builder)) {
        core = build(core.builder).core

        isConfigured = true
    }

    public func registerItemViews(with tableView: UITableView) {

        assert(isConfigured, """
                             Configure DefaultSingleSectionTableViewDatasource before
                             calling registerItemViews().
                             """)

        core.itemToViewMapping.forEach { itemViewType, producer in
            producer.register(itemViewType: itemViewType, at: tableView)
        }
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let cells = cells.currentValue.value.items else { return 0 }
        return cells.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cells = cells.currentValue.value.items,
            indexPath.row < cells.count else { return UITableViewCell() }
        let cell = cells[indexPath.row]
        if let itemViewProducer = core.itemToViewMapping[cell.viewType] {
            return itemViewProducer.view(containingView: tableView, item: cell, for: indexPath)
        } else {
            let fallbackCell = UITableViewCell()
            fallbackCell.textLabel?.text = "Configure itemToViewMapping and call registerItemViews()"
            return fallbackCell
        }
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cells = cells.currentValue.value.items else { return }
        let cell = cells[indexPath.row]
        if cell.viewType.isSelectable {
            core.itemSelected?(cell)
        }
    }

    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if useFixedItemHeights {
            return heightAtIndexPath[indexPath] ?? UITableView.automaticDimension
        } else {
            return UITableView.automaticDimension
        }
    }

    public func tableView(_ tableView: UITableView,
                          willDisplay cell: UITableViewCell,
                          forRowAt indexPath: IndexPath) {
        if useFixedItemHeights {
            heightAtIndexPath[indexPath] = cell.frame.size.height
        }
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
}
