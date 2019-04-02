import Foundation
import DataSourcerer

/// When the listview reaches the topmost ChatBotCell (oldMessagesLoading),
/// the messages older than the current ones are loaded. Without any intervention,
/// the listview would go into an infinite reload cycle because the topmost
/// cell is also shown right after showing the new results. We have to suspend
/// loading more messages until the listview has been scrolled down by our
/// logic in ChatBotTableCellUpdateInterceptor.
class ChatBotLoadOldMessagesEnabledState {

    public private(set) var suspended = true // has to be enabled after loading initial result

    func willChangeCells() {
        suspended = true
    }

    func didChangeCells() {
        suspended = false
    }
}
