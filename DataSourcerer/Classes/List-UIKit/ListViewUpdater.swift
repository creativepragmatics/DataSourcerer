import Dwifft
import Foundation
import UIKit

public struct ListViewUpdater
<Value, P: ResourceParams, E: ResourceError, ItemModelType: ItemModel, SectionModelType: SectionModel> {

    public typealias ListViewStateAlias = ListViewState<Value, P, E, ItemModelType, SectionModelType>
    public typealias UpdateItemsAlias =
        (_ tableView: UITableView, _ previous: ListViewStateAlias, _ next: ListViewStateAlias) -> Void

    public let updateItems: UpdateItemsAlias

    public init(updateItems: @escaping UpdateItemsAlias) {
        self.updateItems = updateItems
    }
}

public extension ListViewUpdater {

    typealias TableViewCellsChange =
        (UITableView, _ previous: ListViewStateAlias, _ next: ListViewStateAlias) -> Void
    typealias AnimateTableViewCellChange =
        (UITableView, _ previous: ListViewStateAlias, _ next: ListViewStateAlias) -> Bool

    init(
        isViewVisible: @escaping (UITableView) -> Bool = { $0.window != nil },
        isUpdateAnimated: @escaping AnimateTableViewCellChange = { _, _, _ in true },
        willChangeCellsInView: TableViewCellsChange? = nil,
        didChangeCellsInView: TableViewCellsChange? = nil
    ) {

        var tableViewDiffCalculator: TableViewDiffCalculator<SectionModelType, ItemModelType>?

        func createDiffCalculator(
            tableView: UITableView,
            initial: ListViewStateAlias
        ) -> TableViewDiffCalculator<SectionModelType, ItemModelType> {

                let calculator = TableViewDiffCalculator<SectionModelType, ItemModelType>(
                    tableView: tableView,
                    initialSectionedValues: initial.dwifftSectionedValues
                )
                calculator.insertionAnimation = .fade
                calculator.deletionAnimation = .fade
                return calculator
        }

        self = ListViewUpdater(
            updateItems: { tableView, previousListViewState, nextListViewState in

                assert(Thread.isMainThread, "ListViewUpdater.updateItems must be called on main thread")

                switch previousListViewState {
                case .readyToDisplay where isViewVisible(tableView) &&
                        isUpdateAnimated(tableView, previousListViewState, nextListViewState):

                    // Previous state was .readyToDisplay. Next state may be either .notReady
                    // (in which case we reset the view to an empty state without any cells),
                    // or .readyToDisplay (which usually results in cells being displayed).

                    if tableViewDiffCalculator == nil {
                        // Use previous cells as initial values such that "next" cells are
                        // inserted with animations
                        tableViewDiffCalculator = createDiffCalculator(
                            tableView: tableView,
                            initial: previousListViewState
                        )
                    }

                    willChangeCellsInView?(tableView, previousListViewState, nextListViewState)
                    tableViewDiffCalculator?.sectionedValues = nextListViewState.dwifftSectionedValues
                    didChangeCellsInView?(tableView, previousListViewState, nextListViewState)
                case .readyToDisplay, .notReady:

                    // Animations disabled or view invisible - skip animations.

                    // Diff calculator must be re-created the next time animations are enabled
                    // or allowed:
                    tableViewDiffCalculator = nil

                    DispatchQueue.main.async { [weak tableView] in
                        guard let tableView = tableView else { return }
                        willChangeCellsInView?(tableView, previousListViewState, nextListViewState)
                        tableView.reloadData()
                        didChangeCellsInView?(tableView, previousListViewState, nextListViewState)
                    }
                }

            }
        )
    }

}
