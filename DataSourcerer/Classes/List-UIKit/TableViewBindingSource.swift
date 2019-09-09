import DifferenceKit
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
    public typealias TableViewStateAlias = ListViewState<Value, P, E, CellModelType, SectionModelType>
    public typealias AnimateTableViewCellChange =
        (UITableView, _ previous: TableViewStateAlias, _ next: TableViewStateAlias) -> Bool
    public typealias TableViewCellsChange =
        (UITableView, _ previous: TableViewStateAlias, _ next: TableViewStateAlias) -> Void

    public private(set) var configuration: ListViewDatasourceConfigurationAlias
    public weak var delegate: AnyObject?
    public weak var datasource: AnyObject?
    public let hideBottomMostSeparatorWithHack: Bool

    private let isUpdateAnimated: AnimateTableViewCellChange
    private let willChangeCellsInView: TableViewCellsChange?
    private let didChangeCellsInView: TableViewCellsChange?
    private var bindingSession: TableViewBindingSessionAlias?
    private let animateCellContentChange: (CellModelType, UITableView, IndexPath) -> Bool

    public lazy var listViewStateProperty: ShareableValueStream
        <ListViewState<Value, P, E, CellModelType, SectionModelType>> = {

        return configuration.state
//            .skipRepeats()
            .observeOnUIThread()
            .shareable(initialValue: .notReady)
    }()

    public var currentSections: [ArraySection<SectionModelType, CellModelType>] = []

    public var listViewState: ListViewState<Value, P, E, CellModelType, SectionModelType> {
        return listViewStateProperty.value
    }

    public init(
        configuration: ListViewDatasourceConfigurationAlias,
        hideBottomMostSeparatorWithHack: Bool = true,
        isUpdateAnimated: @escaping AnimateTableViewCellChange = { _, _, _ in true },
        animateCellContentChange: @escaping (CellModelType, UITableView, IndexPath) -> Bool = { _, _, _ in false },
        willChangeCellsInView: TableViewCellsChange? = nil,
        didChangeCellsInView: TableViewCellsChange? = nil
    ) {
        self.configuration = configuration
        self.hideBottomMostSeparatorWithHack = hideBottomMostSeparatorWithHack
        self.isUpdateAnimated = isUpdateAnimated
        self.animateCellContentChange = animateCellContentChange
        self.willChangeCellsInView = willChangeCellsInView
        self.didChangeCellsInView = didChangeCellsInView

        super.init()
    }

    open func tweak(
        _ configure: (ListViewDatasourceConfigurationAlias) -> ListViewDatasourceConfigurationAlias
    ) {
        assert(bindingSession == nil, "Tweak TableViewBindingSource before binding it")
        configuration = configure(configuration)
    }

    open func bind(
        tableView: UITableView
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
//            .skipRepeats()
            .observe { [weak tableView, weak self] currentState in
                guard let tableView = tableView, let self = self else { return }

                self.updateCells(currentState: currentState, previousState: previousState, tableView: tableView)
                previousState = currentState
            }

        // While the new bindingSession is set, any old session is released
        // and its contained disposable is disposed.
        bindingSession = TableViewBindingSessionAlias(
            tableView: tableView,
            bindingDisposable: disposable
        )
    }

    private func updateCells(
        currentState: ListViewState<Value, P, E, CellModelType, SectionModelType>,
        previousState: ListViewState<Value, P, E, CellModelType, SectionModelType>,
        tableView: UITableView
    ) {
        assert(Thread.isMainThread, "ListViewUpdater.updateItems must be called on main thread")

        var isViewVisible: Bool {
            return tableView.window != nil
        }

        switch previousState {
        case .readyToDisplay where isViewVisible &&
            isUpdateAnimated(tableView, previousState, currentState):

            // Previous state was .readyToDisplay. Next state may be either .notReady
            // (in which case we reset the view to an empty state without any cells),
            // or .readyToDisplay (which usually results in cells being displayed).

            willChangeCellsInView?(tableView, previousState, currentState)
            let changeset = StagedChangeset(source: currentSections, target: currentState.sections ?? [])
            tableView.sourcerer.reload(
                using: changeset,
                with: .fade,
                updateCell: { indexPath, tableView -> TableViewCellUpdateMode in
                    let item = currentSections[indexPath.section].elements[indexPath.row]
                    if animateCellContentChange(item, tableView, indexPath) {
                        return .reload
                    } else {
                        return .reconfigure { [weak self] tableViewCell in
                            guard let self = self else { return }
                            self.configuration.itemViewsProducer.configureView(
                                item,
                                tableViewCell,
                                tableView,
                                indexPath
                            )
                        }
                    }
                },
                setData: { sections in
                    self.currentSections = sections
                }
            )
            didChangeCellsInView?(tableView, previousState, currentState)

        case .readyToDisplay, .notReady:

            // Animations disabled or view invisible - skip animations.

            currentSections = currentState.sections ?? []

            DispatchQueue.main.async { [weak tableView, weak self] in
                guard let tableView = tableView else { return }
                self?.willChangeCellsInView?(tableView, previousState, currentState)
                tableView.reloadData()
                self?.didChangeCellsInView?(tableView, previousState, currentState)
            }
        }

    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        return currentSections.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentSections[section].elements.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        return configuration.itemViewsProducer.produceAndConfigureView(
            itemModel: currentSections[indexPath.section].elements[indexPath.row],
            containingView: tableView,
            indexPath: indexPath
        )
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

        if footerView == nil, hideBottomMostSeparatorWithHack, section == currentSections.count - 1 {
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

        if height == 0, hideBottomMostSeparatorWithHack, section == currentSections.count - 1 {
            return 0.001
        } else {
            return height
        }
    }

    public func tableView(_ tableView: UITableView,
                          willDisplay cell: UITableViewCell,
                          forRowAt indexPath: IndexPath) {

        configuration.willDisplayItem?(cell, currentSections[indexPath.section].elements[indexPath.row], indexPath)

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
            itemModel: currentSections[indexPath.section].elements[indexPath.row],
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
