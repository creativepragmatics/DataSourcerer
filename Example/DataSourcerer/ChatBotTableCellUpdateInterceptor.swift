import DataSourcerer
import Foundation
import UIKit

class ChatBotTableCellUpdateInterceptor {

    private var isScrolledToBottom = false
    private var oldMessageLoadKeepOffset: OldMessageLoadKeepContentOffset = .none

    func isLoadingCellVisible(
        tableView: UITableView,
        state: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>
    ) -> Bool {
        let visibleIndexPaths = tableView.indexPathsForVisibleRows ?? []
        return visibleIndexPaths.contains(where: { visibleIndexPath in
            guard let visibleCell = state.items?[visibleIndexPath.row] else { return false }
            switch visibleCell {
            case let .baseItem(chatBotCell):
                switch chatBotCell {
                case .oldMessagesLoading:
                    return true
                case .message, .header, .error:
                    return false
                }
            case .loading, .error, .noResults:
                return false
            }
        })
    }

    func firstVisibleMessageCell(
        tableView: UITableView,
        state: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>
        ) -> (IdiomaticItemModel<ChatBotCell>, UITableViewCell)? {
        let visibleIndexPaths = tableView.indexPathsForVisibleRows ?? []
        return visibleIndexPaths.compactMap { visibleIndexPath
            -> (IdiomaticItemModel<ChatBotCell>, UITableViewCell)? in

            guard let visibleCell = state.items?[visibleIndexPath.row] else { return nil }
            switch visibleCell {
            case let .baseItem(chatBotCell):
                switch chatBotCell {
                case .message:
                    if let tableViewCell = tableView.cellForRow(at: visibleIndexPath) {
                        return (visibleCell, tableViewCell)
                    } else {
                        return nil
                    }
                case .oldMessagesLoading, .header, .error:
                    return nil
                }
            case .loading, .error, .noResults:
                return  nil
            }
        }.first
    }

    func willChangeCells(
        tableView: UITableView,
        previous: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>,
        next: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>
        ) {
        isScrolledToBottom = self.isScrolledToBottom(tableView: tableView, state: previous)

        // Keep offset if next state is a `loadOldMessages` result:
        if next.isLoadOldMessagesResult,
            let firstVisibleMessage = self.firstVisibleMessageCell(tableView: tableView, state: previous) {

            var offsetFromTop =
                self.offsetFromRootViewTopEdge(cell: firstVisibleMessage.1, tableView: tableView) ?? 0
            if #available(iOS 11.0, *) {
                offsetFromTop -= tableView.adjustedContentInset.top
            } else {
                offsetFromTop -= tableView.contentInset.top
            }

            self.oldMessageLoadKeepOffset = OldMessageLoadKeepContentOffset
                .keepOffset(
                    topMostMessage: firstVisibleMessage.0,
                    cellOffsetFromTop: offsetFromTop
            )
        } else {
            self.oldMessageLoadKeepOffset = .none
        }

        switch next {
        case .notReady:
            break
        case .readyToDisplay:
            UIView.setAnimationsEnabled(false)
        }
    }

    func offsetFromRootViewTopEdge(cell: UITableViewCell, tableView: UITableView) -> CGFloat? {
        guard let superView = tableView.superview else { return nil }

        return superView.convert(cell.frame, from: tableView).minY
    }

    func didChangeCells(
        tableView: UITableView,
        previous: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>,
        next: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>
        ) {

        // Keep content offset on old message prepended

        switch oldMessageLoadKeepOffset {
        case let .keepOffset(cell, cellYPosition):
            oldMessageLoadKeepOffset = .none // reset

            if let rowToScrollTo = next.items?.firstIndex(of: cell) {

                self.oldMessageLoadKeepOffset = .none

                // Calculate total height of all rows before the row
                // that should be scrolled to
                var totalCellsHeight: CGFloat = 0
                for row in (0..<rowToScrollTo) {
                    let indexPath = IndexPath(row: row, section: 0)
                    guard let cell = tableView.cellForRow(at: indexPath) else {
                        break
                    }
                    cell.layoutIfNeeded()
                    totalCellsHeight += cell.frame.height
                }

                tableView.scrollToRow(
                    at: IndexPath(row: rowToScrollTo, section: 0),
                    at: .top,
                    animated: false
                )

                tableView.setContentOffset(
                    CGPoint(x: tableView.contentOffset.x, y: tableView.contentOffset.y - cellYPosition),
                    animated: false
                )

            }
        case .none:
            break
        }

        // Re-enable animations which were probably disabled in `willChangeCells`

        UIView.setAnimationsEnabled(true)

        // Scroll to bottom for new message(s) appended at the bottom

        let scrollToBottom = shouldScrollToBottom(
            tableView: tableView,
            previous: previous,
            next: next
        )

        switch scrollToBottom {
        case let .scrollToBottom(animated):
            tableView.scrollToRow(
                at: IndexPath(row: (next.items ?? []).count - 1, section: 0),
                at: .bottom,
                animated: animated
            )
        case .none:
            break
        }

    }

    func shouldScrollToBottom(
        tableView: UITableView,
        previous: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>,
        next: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>
        ) -> ScrollToBottom {

        switch next {
        case .notReady:
            return .scrollToBottom(animated: false)
        case let .readyToDisplay(loadImpulse, _, _):
            switch loadImpulse.params {
            case .loadOldMessages:
                return .none
            case .loadInitialMessages:
                return .scrollToBottom(animated: false)
            case .loadNewMessages:
                let animated: Bool = {
                    switch previous {
                    case .notReady:
                        return false
                    case .readyToDisplay:
                        return true
                    }
                }()
                if isScrolledToBottom {
                    return .scrollToBottom(animated: animated)
                } else {
                    return .none
                }
            }
        }
    }

    func isScrolledToBottom(
        tableView: UITableView,
        state: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>
        ) -> Bool {
        guard let lastVisibleCell = tableView.visibleCells.last,
            let lastVisibleIndexPath = tableView.indexPath(for: lastVisibleCell),
            lastVisibleIndexPath.row == (state.items ?? []).count - 1 else {
                return false
        }

        let visibleBottomLine: CGFloat

        if #available(iOS 11.0, *) {
            visibleBottomLine = tableView.contentOffset.y +
                tableView.bounds.height -
                tableView.contentInset.bottom -
                tableView.safeAreaInsets.bottom
        } else {
            visibleBottomLine = tableView.contentOffset.y +
                tableView.bounds.height -
                tableView.contentInset.bottom
        }

        return (lastVisibleCell.frame.maxY - visibleBottomLine) <= 20
    }

    enum ScrollToBottom {
        case scrollToBottom(animated: Bool)
        case none
    }

    enum OldMessageLoadKeepContentOffset {
        case none
        case keepOffset(topMostMessage: IdiomaticItemModel<ChatBotCell>, cellOffsetFromTop: CGFloat)
    }
}

extension SingleSectionListViewState where P == ChatBotRequest {

    var isLoadOldMessagesResult: Bool {
        switch self {
        case let .readyToDisplay(loadImpulse, provisioningState, _):
            switch (loadImpulse.params, provisioningState) {
            case (.loadOldMessages, .result):
                return true
            default:
                return false
            }
        case .notReady:
            return false
        }
    }
}
