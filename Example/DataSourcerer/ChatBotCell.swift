import Foundation
import DataSourcerer

enum ChatBotCell : MultiViewTypeItemModel {
    typealias ItemViewType = ViewType
    typealias E = APIError

    case message(ChatBotMessage)
    case header(String)
    case error(APIError)
    case oldMessagesLoading // loading indicator

    init(error: APIError) {
        self = .error(error)
    }

    var itemViewType: ChatBotCell.ViewType {
        switch self {
        case .message, .error, .header:
            return .message
        case .oldMessagesLoading:
            return .loadOldMessages
        }
    }

    enum ViewType: Int, Equatable, CaseIterable {
        case message
        case loadOldMessages
    }
}
