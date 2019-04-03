import DataSourcerer
import Foundation
import UIKit

class ChatBotTableCellUpdateInterceptor {

    private var isScrolledToBottom = false
    private var preserveCellTopOffset: PreserveCellTopOffset = .none

    func willChangeCells(
        tableView: UITableView,
        previous: ChatBotListViewState,
        next: ChatBotListViewState
    ) {
        isScrolledToBottom = self.isScrolledToBottom(tableView: tableView, state: previous)

        // Keep offset if next state is a `loadOldMessages` result:

        if ChatBotListViewState.didLoadOldMessages(previous: previous, next: next),
            let firstVisibleMessage = self.firstVisibleMessageCell(tableView: tableView, state: previous) {

            var offsetFromTop =
                self.offsetFromRootViewTopEdge(cell: firstVisibleMessage.1, tableView: tableView) ?? 0
            if #available(iOS 11.0, *) {
                offsetFromTop -= tableView.adjustedContentInset.top
            } else {
                offsetFromTop -= tableView.contentInset.top
            }

            self.preserveCellTopOffset = PreserveCellTopOffset.keepOffset(
                topMostMessage: firstVisibleMessage.0,
                cellOffsetFromTop: offsetFromTop
            )
        } else {
            self.preserveCellTopOffset = .none
        }

        // Disable animations until didChangeCells

        switch next {
        case .notReady:
            break
        case .readyToDisplay:
            UIView.setAnimationsEnabled(false)
        }
    }

    func didChangeCells(
        tableView: UITableView,
        previous: ChatBotListViewState,
        next: ChatBotListViewState
    ) {

        // Keep content offset when old messages are prepended

        scrollToPreserveCellTopOffset(preserveCellTopOffset, next: next, tableView: tableView)

        // Re-enable animations which were probably disabled in `willChangeCells`

        UIView.setAnimationsEnabled(true)

        // Scroll to bottom for new message(s) appended at the bottom

        let shouldScrollToBottom = self.shouldScrollToBottom(
            tableView: tableView,
            previous: previous,
            next: next
        )

        switch shouldScrollToBottom {
        case let .scrollToBottom(animated):
            guard let items = next.items, items.isEmpty == false else { break }
            tableView.scrollToRow(
                at: IndexPath(row: items.count - 1, section: 0),
                at: .bottom,
                animated: animated
            )
        case .none:
            break
        }

    }

    func shouldScrollToBottom(
        tableView: UITableView,
        previous: ChatBotListViewState,
        next: ChatBotListViewState
        ) -> ScrollToBottom {

        switch next {
        case .notReady:
            return .scrollToBottom(animated: false)
        case .readyToDisplay:
            if ChatBotListViewState.didLoadNewMessages(previous: previous, next: next),
                isScrolledToBottom {
                return .scrollToBottom(animated: true)
            } else if ChatBotListViewState.didLoadInitially(previous: previous, next: next) {
                return .scrollToBottom(animated: false)
            } else {
                return .none
            }
        }
    }

    func scrollToPreserveCellTopOffset(
        _ offset: PreserveCellTopOffset,
        next: ChatBotListViewState,
        tableView: UITableView
    ) {

        switch preserveCellTopOffset {
        case let .keepOffset(cell, cellYPosition):
            preserveCellTopOffset = .none // reset because we only do this once for every insert

            if let rowToScrollTo = next.items?.firstIndex(of: cell) {

                self.preserveCellTopOffset = .none

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
    }

    func isScrolledToBottom(
        tableView: UITableView,
        state: ChatBotListViewState
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

    enum PreserveCellTopOffset {
        case none
        case keepOffset(topMostMessage: IdiomaticItemModel<ChatBotCell>, cellOffsetFromTop: CGFloat)
    }
}

private extension ChatBotTableCellUpdateInterceptor {

    func isLoadingCellVisible(
        tableView: UITableView,
        state: ChatBotListViewState
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
        state: ChatBotListViewState
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

    func offsetFromRootViewTopEdge(cell: UITableViewCell, tableView: UITableView) -> CGFloat? {
        guard let superView = tableView.superview else { return nil }

        return superView.convert(cell.frame, from: tableView).minY
    }
}

extension SingleSectionListViewState
    where Value == PostInitialLoadChatBotState, P == InitialChatBotRequest, E == APIError,
    LI == IdiomaticItemModel<ChatBotCell> {

    static func didLoadOldMessages(
        previous: SingleSectionListViewState,
        next: SingleSectionListViewState
    ) -> Bool {

        switch (previous, next) {
        case (_, .notReady):
            return false
        case let (.notReady, .readyToDisplay(nextState, _)):
            guard let nextOldMessagesState = nextState.value?.value.oldMessagesState else { return false }

            switch nextOldMessagesState.provisioningState {
            case .result where (nextOldMessagesState.value?.value.messages.count ?? 0) > 0:
                return true
            default:
                return false
            }
        case let (.readyToDisplay(previousState, _), .readyToDisplay(nextState, _)):
            guard let nextOldMessagesState = nextState.value?.value.oldMessagesState else { return false }

            switch nextOldMessagesState.provisioningState {
            case .result where (nextOldMessagesState.value?.value.messages.count ?? 0) > 0:
                guard let previousOldMessagesState = previousState.value?.value.oldMessagesState else { return true }
                switch previousOldMessagesState.provisioningState {
                case .loading, .notReady: return true
                case .result:
                    let nextOldMessages = nextOldMessagesState.value?.value.messages ?? []
                    let previousOldMessages = previousOldMessagesState.value?.value.messages ?? []
                    return nextOldMessages != previousOldMessages
                }
            default:
                return false
            }
        }
    }

    static func didLoadNewMessages(
        previous: SingleSectionListViewState,
        next: SingleSectionListViewState
        ) -> Bool {

        switch (previous, next) {
        case (_, .notReady):
            return false
        case let (.notReady, .readyToDisplay(nextState, _)):
            guard let nextNewMessagesState = nextState.value?.value.newMessagesState else { return false }

            switch nextNewMessagesState.provisioningState {
            case .result where (nextNewMessagesState.value?.value.messages.count ?? 0) > 0:
                return true
            default:
                return false
            }
        case let (.readyToDisplay(previousState, _), .readyToDisplay(nextState, _)):
            guard let nextNewMessagesState = nextState.value?.value.newMessagesState else { return false }

            switch nextNewMessagesState.provisioningState {
            case .result where (nextNewMessagesState.value?.value.messages.count ?? 0) > 0:
                guard let previousNewMessagesState = previousState.value?.value.newMessagesState else { return true }
                switch previousNewMessagesState.provisioningState {
                case .loading, .notReady: return true
                case .result:
                    let nextNewMessages = nextNewMessagesState.value?.value.messages ?? []
                    let previousNewMessages = previousNewMessagesState.value?.value.messages ?? []
                    return nextNewMessages != previousNewMessages
                }
            default:
                return false
            }
        }
    }

    static func didLoadInitially(
        previous: SingleSectionListViewState,
        next: SingleSectionListViewState
        ) -> Bool {

        switch (previous, next) {
        case (_, .notReady):
            return false
        case let (.notReady, .readyToDisplay(nextState, _)):
            switch nextState.provisioningState {
            case .result:
                return true
            default:
                return false
            }
        case let (.readyToDisplay(previousState, _), .readyToDisplay(nextState, _)):

            switch nextState.provisioningState {
            case .result where (nextState.value?.value.initialLoadResponse.messages.count ?? 0) > 0:
                switch previousState.provisioningState {
                case .loading, .notReady: return true
                case .result:
                    let nextMessages = nextState.value?.value.initialLoadResponse.messages ?? []
                    let previousMessages = previousState.value?.value.initialLoadResponse.messages ?? []
                    return nextMessages != previousMessages
                }
            default:
                return false
            }
        }
    }
}

extension PostInitialLoadChatBotState {

    static func didLoadOldMessages(
        previous: PostInitialLoadChatBotState,
        next: PostInitialLoadChatBotState
        ) -> Bool {

        switch (previous.oldMessagesState.provisioningState, next.oldMessagesState.provisioningState) {
        case (_, .loading), (_, .notReady):
            return false
        case (.loading, .result), (.notReady, .result):
            return true
        case (.result, .result):
            return compareOptionals(
                previous.oldMessagesState.value,
                next.oldMessagesState.value,
                ==
            )
        }
    }

}

private func compareOptionals<T>(_ lhs: T?, _ rhs: T?, _ compare: (_ lhs: T, _ rhs: T) -> Bool) -> Bool {
    switch (lhs, rhs) {
    case let (lValue?, rValue?):
        return compare(lValue, rValue)
    case (nil, nil):
        return true
    default:
        return false
    }
}
