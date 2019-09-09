import Foundation
import DataSourcerer

enum ChatBotCell : MultiViewTypeItemModel, Equatable {
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

    var differenceIdentifier: String {
        switch self {
        case let .message(message):
            return "__message__\(message.message.hashValue / 3 + message.sentAt.hashValue / 3 + message.senderIsMe.hashValue / 3)"
        case let .header(header):
            return "__header__\(header)"
        case let .error(error):
            return "__error__\(error.localizedDescription)"
        case .oldMessagesLoading:
            return "__oldMessagesLoading__"
        }
    }

    func isContentEqual(to source: ChatBotCell) -> Bool {
        return self == source
//        switch (self, source) {
//        case let (.message(lhs), .message(rhs)):
//            return lhs == rhs
//        case let (.header(lhs), .header(rhs)):
//            return lhs == rhs
//        case let (.error(lhs), .error(rhs)):
//            return lhs == rhs
//        case (.oldMessagesLoading, .oldMessagesLoading):
//            return true
//
//        }
    }

    enum ViewType: Int, Equatable, CaseIterable {
        case message
        case loadOldMessages
    }
}
