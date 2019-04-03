import Foundation
import DataSourcerer

struct ChatBotResponse: Equatable, Codable {
    let messages: [ChatBotMessage]
    let currentAvailableActions: [ChatBotAction]
}

struct ChatBotMessage: Equatable, Codable {
    let senderIsMe: Bool
    let message: String
    let sentAt: Date
}

extension ChatBotMessage {
    init(oldMessageWithCurrentOldestMessage oldestMessage: ChatBotMessage?) {
        let message: String = {
            guard let components = oldestMessage?.message.split(separator: " "),
                components.count == 2 else { return "Message 1000" }
            return components[0] + " " + String((Int(components[1]) ?? 1_000) - 1)
        }()
        self.init(
            senderIsMe: false,
            message: message,
            sentAt: oldestMessage?.sentAt.addingTimeInterval(-60) ?? Date()
        )
    }

    init(newMessageWithCurrentNewestMessage newestMessage: ChatBotMessage?) {
        let message: String = {
            guard let components = newestMessage?.message.split(separator: " "),
                components.count == 2 else { return "Message 1000" }
            return components[0] + " " + String((Int(components[1]) ?? 1_000) + 1)
        }()
        self.init(
            senderIsMe: false,
            message: message,
            sentAt: Date()
        )
    }
}

enum ChatBotAction: String, Equatable, Codable {
    case accept
}
