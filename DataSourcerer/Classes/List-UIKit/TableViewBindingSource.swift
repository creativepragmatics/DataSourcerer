import Foundation
import UIKit

open class TableViewBindingSource
    <Value, P: ResourceParams, E, CellModelType: ItemModel, SectionModelType: SectionModel,
    HeaderItem: SupplementaryItemModel, HeaderItemError, FooterItem: SupplementaryItemModel,
    FooterItemError>: NSObject, UITableViewDelegate,
    UITableViewDataSource where HeaderItem.E == HeaderItemError, FooterItem.E == FooterItemError,
    CellModelType.E == E {

    public typealias ListViewDatasourceConfigurationAlias = ListViewDatasourceConfiguration
        <Value, P, E, CellModelType, UITableViewCell, SectionModelType, HeaderItem,
        UIView, HeaderItemError, FooterItem, UIView, FooterItemError, UITableView>
    public typealias TableViewBindingSessionAlias = TableViewBindingSession
        <Value, P, E, CellModelType, SectionModelType>
    public typealias TableViewUpdaterAlias = ListViewUpdater
        <Value, P, E, CellModelType, SectionModelType>
    public typealias TableViewStateAlias = ListViewState<Value, P, E, CellModelType, SectionModelType>

    public let configuration: ListViewDatasourceConfigurationAlias
    public weak var delegate: AnyObject?
    public weak var datasource: AnyObject?
    public let hideBottomMostSeparatorWithHack: Bool

    private var bindingSession: TableViewBindingSessionAlias?

    public lazy var listViewStateProperty: ShareableValueStream
        <ListViewState<Value, P, E, CellModelType, SectionModelType>> = {

        return configuration.state
            .skipRepeats()
            .observeOnUIThread()
            .shareable(initialValue: .notReady)
    }()

    public var listViewState: ListViewState<Value, P, E, CellModelType, SectionModelType> {
        return listViewStateProperty.value
    }

    private var numberOfSections: Int {
        return listViewState.sectionsAndItems?.count ?? 0
    }

    public init(
        configuration: ListViewDatasourceConfigurationAlias,
        hideBottomMostSeparatorWithHack: Bool = true
    ) {
        self.configuration = configuration
        self.hideBottomMostSeparatorWithHack = hideBottomMostSeparatorWithHack
        super.init()
    }

    open func bind( 
        tableView: UITableView,
        tableViewUpdater: TableViewUpdaterAlias = TableViewUpdaterAlias()
    ) {

        assert(Thread.isMainThread, "bind() can only be called on main thread")

        tableView.delegate = self
        tableView.dataSource = self

        configuration.itemViewsProducer.registerAtContainingView(tableView)
        configuration.headerItemViewAdapter.registerAtContainingView(tableView)
        configuration.footerItemViewAdapter.registerAtContainingView(tableView)

        if hideBottomMostSeparatorWithHack {
            tableView.tableFooterView = UIView()
        }

        var previousState = listViewStateProperty.value

        // Update table with most current cells
        let disposable = listViewStateProperty
            .skipRepeats()
            .observe { [weak tableView] currentState in
                guard let tableView = tableView else { return }

                tableViewUpdater.updateItems(tableView, previousState, currentState)
                previousState = currentState
            }

        // While the new bindingSession is set, any old session is released
        // and its contained disposable is disposed.
        bindingSession = TableViewBindingSessionAlias(
            tableView: tableView,
            tableViewUpdater: tableViewUpdater,
            bindingDisposable: disposable
        )
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        return listViewState.sectionsAndItems?.count ?? 0
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
        let footerView = configuration.footerView(at: IndexPath(row: 0, section: section), in: tableView)

        if footerView == nil, hideBottomMostSeparatorWithHack, section == numberOfSections - 1 {
            return UIView()
        } else {
            return footerView
        }
    }

    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {

        let height = configuration.footerSize(
            at: IndexPath(row: 0, section: section),
            in: tableView
        ).height

        if height == 0, hideBottomMostSeparatorWithHack, section == numberOfSections - 1 {
            return 0.001
        } else {
            return height
        }
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

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        guard let cellView = tableView.cellForRow(at: indexPath) else { return }

        let itemSelection = ListViewDatasourceConfigurationAlias.ItemSelection(
            itemModel: configuration.item(at: indexPath),
            view: cellView,
            indexPath: indexPath,
            containingView: tableView
        )
        configuration.didSelectItem?(itemSelection)

        if let delegate = delegate,
            delegate.responds(to: #selector(tableView(_:didSelectRowAt:))) {
            delegate.tableView!(tableView, didSelectRowAt: indexPath)
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

extension TableViewBindingSource: TableViewUnbindable {

    public func unbind(from tableView: UITableView) {

        if bindingSession?.tableView === tableView {
            bindingSession = nil
        }
    }

}
