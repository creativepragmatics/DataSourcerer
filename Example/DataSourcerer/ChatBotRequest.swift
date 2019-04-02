import Foundation
import DataSourcerer

enum ChatBotRequest: ResourceParams, Equatable {
    case loadInitialMessages(limit: Int)
    case loadOldMessages(oldestKnownMessageId: String, limit: Int)
    case loadNewMessages(newestKnownMessageId: String)

    func isCacheCompatible(_ candidate: ChatBotRequest) -> Bool {
        // In a real-world scenario, you would want to return true if
        // self belongs to the same message list like candidate
        // (e.g. same user is authenticated, and message list id is
        // equal).
        return true
    }

}
