import Foundation
import DataSourcerer

class ChatBotMockStorage {
    var messages: [ChatBotMessage] = []

    func loadInitial(limit: Int, completion: @escaping (ChatBotResponse) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            let newOldestMessages = self.makeOldestMessages(limit: limit)
            self.messages = newOldestMessages
            completion(ChatBotResponse(messages: newOldestMessages, currentAvailableActions: []))
        }
    }

    func loadMoreOldMessages(limit: Int, completion: @escaping (ChatBotResponse) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            let newOldestMessages = self.makeOldestMessages(limit: limit)
            self.messages = newOldestMessages + self.messages
            completion(ChatBotResponse(messages: newOldestMessages, currentAvailableActions: []))
        }
    }

    func loadNewMessage(completion: @escaping (ChatBotResponse) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let newMessage = self.makeNewMessage()
            self.messages += [newMessage]
            completion(ChatBotResponse(messages: [newMessage], currentAvailableActions: []))
        }
    }

    func makeOldestMessages(limit: Int) -> [ChatBotMessage] {
        var oldestMessage = self.messages.first
        var oldestMessages = [ChatBotMessage]()
        (1...limit).forEach { _ in
            let message = ChatBotMessage(oldMessageWithCurrentOldestMessage: oldestMessage)
            oldestMessages.insert(message, at: 0)
            oldestMessage = message
        }
        return oldestMessages
    }

    func makeNewMessage() -> ChatBotMessage {
        return ChatBotMessage(newMessageWithCurrentNewestMessage: self.messages.last)
    }
}
