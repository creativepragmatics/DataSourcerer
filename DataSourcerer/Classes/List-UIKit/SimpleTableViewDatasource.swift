import Foundation
import UIKit

open class SimpleTableViewDatasource
    <Value, P: Parameters, E: StateError, Cell: ListItem, Section: ListSection,
    HeaderItem: SupplementaryItem, FooterItem: SupplementaryItem>: NSObject, UITableViewDelegate,
    UITableViewDataSource where HeaderItem.E == FooterItem.E {
    public typealias Core = ListViewDatasourceCore
        <Value, P, E, Cell, UITableViewCell, Section, HeaderItem,
        UIView, FooterItem, UIView, UITableView>

    public let core: Core
    public weak var delegate: UITableViewDelegate?
    public weak var datasource: UITableViewDataSource?

    public var sections: ListSections<Cell, Section> {
        return core.sections
    }

    public init(core: Core, tableView: UITableView) {
        self.core = core
        super.init()

        core.itemViewAdapter.registerAtContainingView(tableView)
        core.headerItemViewAdapter.registerAtContainingView(tableView)
        core.footerItemViewAdapter.registerAtContainingView(tableView)
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return core.section(at: section).items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return core.itemView(at: indexPath, in: tableView)
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return core.headerView(at: IndexPath(row: 0, section: section), in: tableView)
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return core.headerSize(at: IndexPath(row: 0, section: section),
                               in: tableView).height
    }

    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return core.footerView(at: IndexPath(row: 0, section: section), in: tableView)
    }

    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return core.footerSize(at: IndexPath(row: 0, section: section),
                               in: tableView).height
    }

    public func tableView(_ tableView: UITableView,
                          willDisplay cell: UITableViewCell,
                          forRowAt indexPath: IndexPath) {

        core.willDisplayItem?(cell, core.item(at: indexPath), indexPath)

        if let delegate = delegate,
            delegate.responds(to: #selector(tableView(_:willDisplay:forRowAt:))) {
            delegate.tableView!(tableView, willDisplay: cell, forRowAt: indexPath)
        }
    }

    public func tableView(_ tableView: UITableView,
                          willDisplayHeaderView view: UIView,
                          forSection section: Int) {
        let indexPath = IndexPath(row: 0, section: section)
        if let headerItem = core.headerItemAtIndexPath?(indexPath) {
            core.willDisplayHeaderItem?(view, headerItem, indexPath)
        }

        if let delegate = delegate,
            delegate.responds(to: #selector(tableView(_:willDisplayHeaderView:forSection:))) {
            delegate.tableView!(tableView, willDisplayHeaderView: view, forSection: section)
        }
    }

    public func tableView(_ tableView: UITableView,
                          willDisplayFooterView view: UIView,
                          forSection section: Int) {
        let indexPath = IndexPath(row: 0, section: section)
        if let footerItem = core.footerItemAtIndexPath?(indexPath) {
                core.willDisplayFooterItem?(view, footerItem, indexPath)
        }

        if let delegate = delegate,
            delegate.responds(to: #selector(tableView(_:willDisplayFooterView:forSection:))) {
            delegate.tableView!(tableView, willDisplayFooterView: view, forSection: section)
        }
    }

    open override func responds(to aSelector: Selector!) -> Bool {
        return super.responds(to: aSelector)
            || delegate?.responds(to: aSelector) ?? false
            || datasource?.responds(to: aSelector) ?? false
    }

    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if delegate?.responds(to: aSelector) ?? false {
            return delegate
        } else if datasource?.responds(to: aSelector) ?? false {
            return datasource
        }

        return nil
    }

}

public extension SimpleTableViewDatasource where Section == NoSection {

    var cellsProperty: ShareableValueStream<SingleSectionListItems<Cell>> {

        return core.listDatasource.stateAndSections
            .map { SingleSectionListItems<Cell>(sections: $0.sections) }
            .observeOnUIThread()
            .shareable(initialValue: .notReady)
    }

    var cells: SingleSectionListItems<Cell> {
        return SingleSectionListItems<Cell>(sections: core.sections)
    }
}

///// Idiomatic implementation for a single section tableview
///// with support for loading indicator, "no results" cell
///// and error cell.
///// Configuration has to be done before the `cells`
///// property is accessed.
//open class IdiomaticSingleSectionTableViewDatasource
//    <Value, P: Parameters, E: StateError, BaseItem: Equatable>:
//    NSObject, UITableViewDelegate, UITableViewDataSource {
//    public typealias Cell = IdiomaticListItem<BaseItem>
//    public typealias Cells = SingleSectionListItems<Cell>
//    public typealias CellViewProducer = SimpleTableViewCellProducer<Cell>
//    public typealias StatesObservable = AnyObservable<State<Value, P, E>>
//    public typealias Core = ListViewDatasourceCore<CellViewProducer, PlainListSection>
//
//    public private(set) var core = Core()
//    private let statesObservable: StatesObservable
//
//    /// If true, use heightAtIndexPath to store item heights. Most likely
//    /// only makes sense in TableViews with autolayouted cells.
//    public var useFixedItemHeights = false
//    public var heightAtIndexPath: [IndexPath: CGFloat] = [:]
//
//    public lazy var cells: ObservableProperty<Cells> = {
//
//        return self.statesObservable
//            .map({ state -> (TransformedValue) in
//                state.
//            })
//            .map(self.core.stateToItems)
//            .observeOnUIThread()
//            .property(initialValue: Core.Item.notReady)
//    }()
//
//    public init(statesObservable: StatesObservable) {
//        self.statesObservable = statesObservable
//        super.init()
//    }
//
//    public func configure(_ configureWithBuilder: (inout Configuration.Builder) -> Void,
//                          tableView: UITableView) {
//        var builder = Configuration.Builder()
//        configureWithBuilder(&builder)
//        _configuration = builder.configuration
//        registerItemViews(with: tableView)
//    }
//
//    private func registerItemViews(with tableView: UITableView) {
//        configuration.idiomaticItemToViewMapping.forEach { itemViewType, producer in
//            producer.register(itemViewType: itemViewType, at: tableView)
//        }
//    }
//
//
//}
