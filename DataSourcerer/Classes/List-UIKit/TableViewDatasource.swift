import Foundation
import UIKit

open class TableViewDatasource
    <Value, P: ResourceParams, E, CellModelType: ItemModel, SectionModelType: SectionModel,
    HeaderItem: SupplementaryItemModel, HeaderItemError, FooterItem: SupplementaryItemModel,
    FooterItemError>: NSObject, UITableViewDelegate,
    UITableViewDataSource where HeaderItem.E == HeaderItemError, FooterItem.E == FooterItemError,
    CellModelType.E == E {
    public typealias Configuration = ListViewDatasourceConfiguration
        <Value, P, E, CellModelType, UITableViewCell, SectionModelType, HeaderItem,
        UIView, HeaderItemError, FooterItem, UIView, FooterItemError, UITableView>

    public let configuration: Configuration
    public weak var delegate: UITableViewDelegate?
    public weak var datasource: UITableViewDataSource?

    public var sections: ListViewState<CellModelType, SectionModelType> {
        return configuration.sections
    }

    public init(configuration: Configuration, tableView: UITableView) {
        self.configuration = configuration
        super.init()

        configuration.itemViewsProducer.registerAtContainingView(tableView)
        configuration.headerItemViewAdapter.registerAtContainingView(tableView)
        configuration.footerItemViewAdapter.registerAtContainingView(tableView)
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        return configuration.sections.sectionsWithItems?.count ?? 0
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return configuration.section(at: section).items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return configuration.itemView(at: indexPath, in: tableView)
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return configuration.headerView(at: IndexPath(row: 0, section: section), in: tableView)
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return configuration.headerSize(at: IndexPath(row: 0, section: section),
                                        in: tableView).height
    }

    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return configuration.footerView(at: IndexPath(row: 0, section: section), in: tableView)
    }

    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return configuration.footerSize(at: IndexPath(row: 0, section: section),
                                        in: tableView).height
    }

    public func tableView(_ tableView: UITableView,
                          willDisplay cell: UITableViewCell,
                          forRowAt indexPath: IndexPath) {

        configuration.willDisplayItem?(cell, configuration.item(at: indexPath), indexPath)

        if let delegate = delegate,
            delegate.responds(to: #selector(tableView(_:willDisplay:forRowAt:))) {
            delegate.tableView!(tableView, willDisplay: cell, forRowAt: indexPath)
        }
    }

    public func tableView(_ tableView: UITableView,
                          willDisplayHeaderView view: UIView,
                          forSection section: Int) {
        let indexPath = IndexPath(row: 0, section: section)
        if let headerItem = configuration.headerItemAtIndexPath?(indexPath) {
            configuration.willDisplayHeaderItem?(view, headerItem, indexPath)
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
        if let footerItem = configuration.footerItemAtIndexPath?(indexPath) {
                configuration.willDisplayFooterItem?(view, footerItem, indexPath)
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

public extension TableViewDatasource where SectionModelType == NoSection {

    var cellsProperty: ShareableValueStream<SingleSectionListViewState<CellModelType>> {

        return configuration.stateAndSections
            .map { SingleSectionListViewState<CellModelType>(sections: $0.listViewState) }
            .observeOnUIThread()
            .shareable(initialValue: .notReady)
    }

    var cells: SingleSectionListViewState<CellModelType> {
        return SingleSectionListViewState<CellModelType>(sections: configuration.sections)
    }
}
