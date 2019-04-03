import Foundation
import DataSourcerer

struct InitialChatBotRequest: ResourceParams, Equatable {
    let limit: Int

    func isCacheCompatible(_ candidate: InitialChatBotRequest) -> Bool {
        // In a real-world scenario, you would want to return true if
        // self belongs to the same message list like candidate
        // (e.g. same user is authenticated, and message list id is
        // equal).
        return true
    }
}

struct OldMessagesChatBotRequest: ResourceParams, Equatable {
    let oldestKnownMessageId: String
    let limit: Int

    func isCacheCompatible(_ candidate: OldMessagesChatBotRequest) -> Bool {
        // In a real-world scenario, you would want to return true if
        // self belongs to the same message list like candidate
        // (e.g. same user is authenticated, and message list id is
        // equal).
        return true
    }
}

struct NewMessagesChatBotRequest: ResourceParams, Equatable {
    let newestKnownMessageId: String

    func isCacheCompatible(_ candidate: NewMessagesChatBotRequest) -> Bool {
        // In a real-world scenario, you would want to return true if
        // self belongs to the same message list like candidate
        // (e.g. same user is authenticated, and message list id is
        // equal).
        return true
    }
}
