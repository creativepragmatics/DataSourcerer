import DataSourcerer
import DifferenceKit
import Foundation
import MulticastDelegate
import ReactiveSwift
import UIKit

public extension Resource.ListBinding where View == UITableViewCell, ContainerView == UITableView {
    typealias AnimateTableViewCellChange =
        (UITableView, _ previous: ListViewState, _ next: ListViewState) -> Bool
    typealias AnimateTableViewCellContentChange = (ItemModelType, ContainerView, IndexPath) -> Bool
    typealias TableViewCellsChange =
        (UITableView, _ previous: ListViewState, _ next: ListViewState) -> Void

    /// Binds this ListBinding to a UITableView. The binding will only be active
    /// as long as the returned `Disposable` is retained.
    ///
    /// An idiomatic way of retaining the binding is importing the ReactiveCocoa module
    /// and adding the `Disposable` to the ViewController's lifetime:
    ///
    ///     Lifetime.of(viewController) += listBinding
    ///         .bind(to: tableView, addRefreshControl: true)
    func bind(
        to tableView: ContainerView,
        addRefreshControl: RefreshControl,
        delegate: (NSObject & UITableViewDelegate)? = nil,
        datasource: (NSObject & UITableViewDataSource)? = nil,
        animateTableViewCellChange: @escaping AnimateTableViewCellChange = { _, _, _ in true },
        animateTableViewCellContentChange: @escaping AnimateTableViewCellContentChange =
            { _, _, _ in false }
    ) -> Disposable {
        assert(Thread.isMainThread, "bind() can only be called on the main thread")

        let itemViewMakerWithSideEffects: Property<UIViewItemMaker> = self.itemViewMaker
            .map { [weak tableView] in
                if let tableView = tableView {
                    $0.registerAtContainerView(tableView)
                }
                return $0
            }

        let listViewState = self.datasource.state
            .combineLatest(with: listViewStateMaker)
            .map { state, maker in maker(state: state) }
        let currentSections = MutableProperty<[DiffableSection]>([])

        let rootDelegate = TableViewDelegate(
            binding: self,
            sections: Property(capturing: currentSections),
            otherDelegate: delegate,
            otherDatasource: datasource
        )
        tableView.dataSource = rootDelegate
        tableView.delegate = rootDelegate

        let disposable = CompositeDisposable()

        disposable += listViewState.producer
            .prefix(value: .notReady) // Ensures that the first value isn't swallowed by combinePrevious
            .combinePrevious()
            .combineLatest(with: itemViewMakerWithSideEffects)
            .combineLatest(with: supplementaryViewMaker)
            .startWithValues { args in
                let (((previous, current), itemViewMaker), _) = args
                updateCells(
                    currentState: current,
                    previousState: previous,
                    currentSections: currentSections,
                    tableView: tableView,
                    itemViewMaker: itemViewMaker,
                    animateTableViewCellChange: animateTableViewCellChange,
                    animateTableViewCellContentChange: animateTableViewCellContentChange,
                    willUpdateListView: willUpdateListView.input,
                    didUpdateListView: didUpdateListView.input
                )
            }

        switch addRefreshControl {
        case .none:
            break
        case let .onTableView(makeQuery):
            let refreshControl = UIRefreshControl()
            let refreshTarget = RefreshTarget { [state = self.datasource.state] in
                let query = makeQuery(state.value)
                disposable += self.datasource
                    .refresh(query: query, skipIfSuccessfullyLoaded: false)
                    .start()
            }
            refreshControl.addTarget(
                refreshTarget,
                action: #selector(RefreshTarget.refresh),
                for: .valueChanged
            )
            disposable += refreshControl.sourcerer.endRefreshing(when: self.datasource.loadingEnded())
            disposable += AnyDisposable {
                withExtendedLifetime(refreshTarget, {})
            }
            tableView.refreshControl = refreshControl
        }

        disposable += AnyDisposable { [weak tableView] in
            tableView?.delegate = nil
            tableView?.dataSource = nil
            // We also have to hold onto rootDelegate or
            // it will be released right after bind() returns.
            withExtendedLifetime(rootDelegate, {})
        }

        return ScopedDisposable(disposable)
    }

    private func updateCells(
        currentState: ListViewState,
        previousState: ListViewState,
        currentSections: MutableProperty<[DiffableSection]>,
        tableView: UITableView,
        itemViewMaker: UIViewItemMaker,
        animateTableViewCellChange: AnimateTableViewCellChange,
        animateTableViewCellContentChange: AnimateTableViewCellContentChange,
        willUpdateListView: Signal<ListViewStateChange, Never>.Observer,
        didUpdateListView: Signal<ListViewStateChange, Never>.Observer
    ) {
        assert(Thread.isMainThread, "updateCells must be called on the main thread")

        var isViewVisible: Bool {
            return tableView.window != nil
        }

        switch previousState {
        case .readyToDisplay where isViewVisible &&
                animateTableViewCellChange(tableView, previousState, currentState):

            // Previous state was .readyToDisplay. Next state may be either .notReady
            // (in which case we reset the view to an empty state without any cells),
            // or .readyToDisplay (which usually results in cells being displayed).

            willUpdateListView.send(
                value: .init(
                    previousState: previousState,
                    nextState: currentState,
                    containingView: tableView
                )
            )
            let changeset = StagedChangeset(
                source: currentSections.value,
                target: currentState.sections ?? []
            )
            tableView.sourcerer.reload(
                using: changeset,
                with: .fade,
                updateCell: { indexPath, tableView -> TableViewCellUpdateMode in
                    let item = currentSections.value[indexPath.section].elements[indexPath.row]
                    if animateTableViewCellContentChange(item, tableView, indexPath) {
                        return .reload
                    } else {
                        return .reconfigure { tableViewCell in
                            itemViewMaker.configureView(
                                item,
                                tableViewCell,
                                tableView,
                                indexPath
                            )
                        }
                    }
                },
                setData: { sections in
                    currentSections.value = sections
                }
            )
            didUpdateListView.send(
                value: .init(
                    previousState: previousState,
                    nextState: currentState,
                    containingView: tableView
                )
            )

        case .readyToDisplay, .notReady:

            // Animations disabled or view invisible - skip animations.

            currentSections.value = currentState.sections ?? []

            if isViewVisible {
                willUpdateListView.send(
                    value: .init(
                        previousState: previousState,
                        nextState: currentState,
                        containingView: tableView
                    )
                )
            }
            tableView.reloadData()
            if isViewVisible {
                didUpdateListView.send(
                    value: .init(
                        previousState: previousState,
                        nextState: currentState,
                        containingView: tableView
                    )
                )
            }
        }

    }
}

public extension Resource.ListBinding {
    enum RefreshControl {
        case none
        case onTableView(makeQuery: (Resource.State) -> Query)
    }
}

public extension Resource.ListBinding
where View == UITableViewCell, ContainerView == UITableView, Query == NoQuery {

    func bind(
        to tableView: ContainerView,
        addRefreshControl: Bool,
        delegate: (NSObject & UITableViewDelegate)? = nil,
        datasource: (NSObject & UITableViewDataSource)? = nil,
        animateTableViewCellChange: @escaping AnimateTableViewCellChange = { _, _, _ in true },
        animateTableViewCellContentChange: @escaping AnimateTableViewCellContentChange =
            { _, _, _ in false }
    ) -> Disposable {
        bind(
            to: tableView,
            addRefreshControl: addRefreshControl ?
                .onTableView(makeQuery: { _ in NoQuery() }) : .none,
            delegate: delegate,
            datasource: datasource,
            animateTableViewCellChange: animateTableViewCellChange,
            animateTableViewCellContentChange: animateTableViewCellContentChange
        )
    }
}

final class RefreshTarget {
    let _refresh: () -> Void

    init(refresh: @escaping () -> Void) {
        _refresh = refresh
    }

    @objc
    func refresh() {
        _refresh()
    }
}

private extension Resource.ListBinding {
    final class TableViewDelegate: MulticastDelegate, UITableViewDelegate, UITableViewDataSource {
        typealias ListBindingType = Resource.ListBinding<
            ItemModelType,
            SectionModelType,
            UITableViewCell,
            UITableView
        >

        private let binding: ListBindingType
        private let sections: Property<[DiffableSection]>

        init(
            binding: ListBindingType,
            sections: Property<[DiffableSection]>,
            otherDelegate: (NSObject & UITableViewDelegate)?,
            otherDatasource: (NSObject & UITableViewDataSource)?
        ) {
            self.binding = binding
            self.sections = sections
            let otherDelegates = ([otherDelegate as NSObject?, otherDatasource as NSObject?])
                .compactMap { $0 }
            super.init(delegates: otherDelegates)
        }

        private func section(at index: Int) -> ArraySection<SectionModelType, ItemModelType>? {
            return sections.value[index]
        }

        func numberOfSections(in tableView: UITableView) -> Int {
            sections.value.count
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            guard let section = self.section(at: section) else { return 0 }
            return section.elements.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard let section = self.section(at: indexPath.section) else { return UITableViewCell() }
            let itemModel = section.elements[indexPath.row]
            return binding.itemViewMaker.value.produceAndConfigureView(
                itemModel: itemModel,
                containingView: tableView,
                indexPath: indexPath
            )
        }

        private func supplementaryTitle(for section: Int, tableView: UITableView, header: Bool)
        -> String? {
            guard
                let headerView = supplementaryView(for: section, tableView: tableView, header: header)
            else { return nil }

            switch headerView {
            case .none, .uiView:
                return nil
            case let .title(string):
                return string
            }
        }

        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            supplementaryTitle(for: section, tableView: tableView, header: true)
        }

        func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            supplementaryTitle(for: section, tableView: tableView, header: false)
        }

        func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
            guard let section = self.section(at: indexPath.section) else { return }
            let itemModel = section.elements[indexPath.row]
            binding.willDisplayItem.input.send(
                value: .init(
                    itemModel: itemModel,
                    view: cell,
                    indexPath: indexPath,
                    containingView: tableView
                )
            )
        }

        private func supplementaryView(for section: Int, tableView: UITableView, header: Bool)
        -> ListBindingType.SupplementaryView? {
            guard let arraySection = self.section(at: section) else { return nil }

            return binding.supplementaryViewMaker.value.make(
                .init(
                    kind: header ?
                        .sectionHeader(arraySection.model) :
                        .sectionFooter(arraySection.model),
                    indexPath: IndexPath(item: 0, section: section),
                    containingView: tableView
                )
            )
        }

        private func supplementaryUIViewMaker(for section: Int, tableView: UITableView, header: Bool)
        -> ListBindingType.SupplementaryView.UIViewMaker? {
            guard
                let headerView = supplementaryView(for: section, tableView: tableView, header: header)
            else { return nil }

            switch headerView {
            case .none, .title:
                return nil
            case let .uiView(maker):
                return maker
            }
        }

        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
            supplementaryUIViewMaker(for: section, tableView: tableView, header: true)?.makeView()
        }

        func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
            supplementaryUIViewMaker(for: section, tableView: tableView, header: false)?.makeView()
        }

        func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
            supplementaryUIViewMaker(for: section, tableView: tableView, header: true)?
                .estimatedHeight?() ?? 0
        }

        func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
            supplementaryUIViewMaker(for: section, tableView: tableView, header: false)?
                .estimatedHeight?() ?? 0
        }

        func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
            supplementaryUIViewMaker(for: section, tableView: tableView, header: true)?.height?() ?? 0
        }

        func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
            supplementaryUIViewMaker(for: section, tableView: tableView, header: false)?.height?() ?? 0
        }

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            guard
                let section = self.section(at: indexPath.section),
                let cell = tableView.cellForRow(at: indexPath)
            else { return }
            binding.didSelectItem.input.send(
                value: .init(
                    itemModel: section.elements[indexPath.row],
                    view: cell,
                    indexPath: indexPath,
                    containingView: tableView
                )
            )
        }
    }
}
