import Foundation
import DataSourcerer

class ChatBotResourceStatesProvider {

    typealias State = ResourceState<ChatBotResponse, ChatBotRequest, APIError>

    func resourceStates(loadImpulseEmitter: AnyLoadImpulseEmitter<ChatBotRequest>)
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
}
