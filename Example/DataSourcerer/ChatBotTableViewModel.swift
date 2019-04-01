import DataSourcerer
import Foundation

class ChatBotTableViewModel {

    typealias State = ResourceState<ChatBotResponse, ChatBotRequest, APIError>

    lazy var datasource: Datasource<ChatBotResponse, ChatBotRequest, APIError> = {

        let initialParams = ChatBotRequest.loadInitialMessages(limit: 20)
        let initialImpulse = LoadImpulse(params: initialParams, type: .initial)
        let loadImpulseEmitter = SimpleLoadImpulseEmitter(initialImpulse: initialImpulse).any

        let cachedStates = Datasource.CacheBehavior.none
            .apply(on: reducedStatesFromAPI(loadImpulseEmitter: loadImpulseEmitter),
                   loadImpulseEmitter: loadImpulseEmitter)
            .skipRepeats()
            .observeOnUIThread()

        let shareableCachedState = cachedStates
            .shareable(initialValue: .notReady)

        return Datasource<ChatBotResponse, ChatBotRequest, APIError>(
            shareableCachedState,
            loadImpulseEmitter: loadImpulseEmitter
        )
    }()

    init() {

    }

    var newMessageTimer: Timer?

    func startReceivingNewMessages() {
        newMessageTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            let loadImpulse = LoadImpulse(
                params: ChatBotRequest.loadNewMessages(newestKnownMessageId: ""),
                type: LoadImpulseType(mode: LoadImpulseType.Mode.partialLoad, issuer: .system)
            )
            self?.datasource.loadImpulseEmitter.emit(loadImpulse: loadImpulse, on: .current)
        })
    }

    func stopReceivingNewMessages() {
        newMessageTimer?.invalidate()
    }

    private func mockStatesFromAPI(loadImpulseEmitter: AnyLoadImpulseEmitter<ChatBotRequest>)
        -> ValueStream<ResourceState<ChatBotResponse, ChatBotRequest, APIError>> {

            return ValueStream
                <ResourceState<ChatBotResponse, ChatBotRequest, APIError>> { sendState, disposable in

                    let storage = ChatBotMockStorage()

                    disposable += loadImpulseEmitter.observe { loadImpulse in

                        func sendError(_ error: APIError) {
                            sendState(State.error(
                                error: error,
                                loadImpulse: loadImpulse,
                                fallbackValueBox: nil
                            ))
                        }

                        let loadingState = State.loading(
                            loadImpulse: loadImpulse,
                            fallbackValueBox: nil,
                            fallbackError: nil
                        )

                        sendState(loadingState)

                        switch loadImpulse.params {
                        case let .loadInitialMessages(limit):
                            storage.loadInitial(limit: limit, completion: { response in
                                let state = State.value(
                                    valueBox: EquatableBox(response),
                                    loadImpulse: loadImpulse,
                                    fallbackError: nil
                                )
                                sendState(state)
                            })
                        case .loadOldMessages(_, let limit):
                            storage.loadMoreOldMessages(limit: limit, completion: { response in
                                let state = State.value(
                                    valueBox: EquatableBox(response),
                                    loadImpulse: loadImpulse,
                                    fallbackError: nil
                                )
                                sendState(state)
                            })
                        case .loadNewMessages:
                            storage.loadNewMessage(completion: { response in
                                let state = State.value(
                                    valueBox: EquatableBox(response),
                                    loadImpulse: loadImpulse,
                                    fallbackError: nil
                                )
                                sendState(state)
                            })
                        }
                    }
            }
    }

    private func reducedStatesFromAPI(loadImpulseEmitter: AnyLoadImpulseEmitter<ChatBotRequest>)
        -> AnyObservable<ResourceState<ChatBotResponse, ChatBotRequest, APIError>> {

        let statesFromAPI = self.mockStatesFromAPI(loadImpulseEmitter: loadImpulseEmitter)
        return statesFromAPI
            .reduce { cumulative, next -> State in

                guard let loadImpulse = next.loadImpulse else {
                    return cumulative ?? next
                }

                switch next.provisioningState {
                case .loading:
                    if let cumulative = cumulative {
                        return State.loading(
                            loadImpulse: loadImpulse,
                            fallbackValueBox: cumulative.cacheCompatibleValue(for: loadImpulse),
                            fallbackError: cumulative.cacheCompatibleError(for: loadImpulse)
                        )
                    } else {
                        return State.loading(
                            loadImpulse: loadImpulse,
                            fallbackValueBox: nil,
                            fallbackError: nil
                        )
                    }
                case .notReady:
                    return State.notReady
                case .result:

                    guard let cumulativeResponse =
                        (cumulative?.cacheCompatibleValue(for: loadImpulse))?.value else {
                            return next
                    }

                    guard let nextResponse = next.value?.value else {
                        if let nextError = next.error {
                            return State.error(
                                error: nextError,
                                loadImpulse: loadImpulse,
                                fallbackValueBox: cumulative?.cacheCompatibleValue(for: loadImpulse)
                            )
                        } else {
                            return cumulative ?? .notReady
                        }
                    }

                    switch loadImpulse.params {
                    case .loadInitialMessages:
                        return State.value(
                            valueBox: EquatableBox(
                                ChatBotResponse(
                                    messages: nextResponse.messages,
                                    currentAvailableActions: nextResponse.currentAvailableActions
                                )
                            ),
                            loadImpulse: loadImpulse,
                            fallbackError: next.error
                        )
                    case .loadOldMessages:
                        return State.value(
                            valueBox: EquatableBox(
                                ChatBotResponse(
                                    messages: nextResponse.messages + cumulativeResponse.messages,
                                    currentAvailableActions: cumulativeResponse.currentAvailableActions
                                )
                            ),
                            loadImpulse: loadImpulse,
                            fallbackError: next.error
                        )
                    case .loadNewMessages:
                        return State.value(
                            valueBox: EquatableBox(
                                ChatBotResponse(
                                    messages: cumulativeResponse.messages + nextResponse.messages,
                                    currentAvailableActions: nextResponse.currentAvailableActions
                                )
                            ),
                            loadImpulse: loadImpulse,
                            fallbackError: next.error
                        )
                    }
                }
            }
    }

}

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            let newOldestMessages = self.makeOldestMessages(limit: limit)
            self.messages = newOldestMessages + self.messages
            completion(ChatBotResponse(messages: newOldestMessages, currentAvailableActions: []))
        }
    }

    func loadNewMessage(completion: @escaping (ChatBotResponse) -> Void) {
        let newMessage = makeNewMessage()
        messages += [newMessage]
        completion(ChatBotResponse(messages: [newMessage], currentAvailableActions: []))
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
