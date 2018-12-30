import Foundation
import UIKit

open class DefaultSingleSectionTableViewDatasource
    <Datasource: DatasourceProtocol, CellViewProducer: TableViewCellProducer>:
    NSObject, UITableViewDelegate, UITableViewDataSource where
CellViewProducer.Item : DefaultListItem, CellViewProducer.Item.E == Datasource.E {

    public typealias Core = DefaultSingleSectionListViewDatasourceCore<Datasource, CellViewProducer>

    private let datasource: Datasource
    public var core: Core

    /// If true, use heightAtIndexPath to store item heights. Most likely
    /// only makes sense in TableViews with autolayouted cells.
    public var useFixedItemHeights = false
    public var heightAtIndexPath: [IndexPath: CGFloat] = [:]

    public lazy var cells: UIObservable<Core.Items> = {
        return UIObservable(self.cellsProducer.any)
    }()

    private lazy var cellsProducer: DefaultSingleSectionListItemsProducer
        <CellViewProducer.Item, Datasource> = {
        return DefaultSingleSectionListItemsProducer(datasource: self.datasource,
                                                     stateToMappedValue: self.core.stateToItems)
    }()

    public init(datasource: Datasource) {
        self.datasource = datasource
        self.core = DefaultSingleSectionListViewDatasourceCore()
    }

    public func configure(with tableView: UITableView, _ build: (Core.Builder) -> (Core.Builder)) {
        core = build(core.builder).core

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
            fallbackCell.textLabel?.text = "Set DefaultSingleSectionListViewDatasourceCore.itemToViewMapping"
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
