import Foundation
import UIKit
import DataSourcerer

class ChatBotTableCellUpdateInterceptor {

    var isScrolledToBottom = false
    var oldMessageLoadOffset: OldMessageLoadOffset?

    func willChangeCells(
        tableView: UITableView,
        previous: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>,
        next: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>
        ) {
        isScrolledToBottom = self.isScrolledToBottom(tableView: tableView, state: previous)
        oldMessageLoadOffset = OldMessageLoadOffset(
            contentHeight: tableView.contentSize.height,
            contentOffset: tableView.contentOffset.y
        )

        switch next {
        case .notReady:
            break
        case .readyToDisplay:
            UIView.setAnimationsEnabled(false)
        }
    }

    func didChangeCells(
        tableView: UITableView,
        previous: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>,
        next: SingleSectionListViewState<ChatBotRequest, IdiomaticItemModel<ChatBotCell>>
        ) {

        UIView.setAnimationsEnabled(true)

        // Scroll to bottom on new message(s)

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

        // Keep content offset on old message prepended

        if let oldMessageLoadOffset = self.oldMessageLoadOffset {
            switch next {
            case let .readyToDisplay(loadImpulse, _):
                switch loadImpulse.params {
                case .loadOldMessages:
                    let heightDiff = tableView.contentSize.height - oldMessageLoadOffset.contentHeight
                    let newOffsetY = oldMessageLoadOffset.contentOffset + heightDiff
                    tableView.contentOffset = CGPoint(x: 0, y: newOffsetY)
                case .loadInitialMessages, .loadNewMessages:
                    break
                }
            case .notReady:
                break
            }
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
        case let .readyToDisplay(loadImpulse, _):
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

        return (lastVisibleCell.frame.maxY - visibleBottomLine) <= 10
    }

    enum ScrollToBottom {
        case scrollToBottom(animated: Bool)
        case none
    }

    struct OldMessageLoadOffset {
        let contentHeight: CGFloat
        let contentOffset: CGFloat
    }
}
