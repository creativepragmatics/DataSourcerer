import Foundation
import DataSourcerer

struct NewMessagesChatBotStates {

    let storage: ChatBotMockStorage
    let loadImpulseEmitter = SimpleLoadImpulseEmitter<NewMessagesChatBotRequest>(
        initialImpulse: nil
    )

    init(storage: ChatBotMockStorage) {
        self.storage = storage
    }

    func states()
        -> AnyObservable<ResourceState<ChatBotResponse, NewMessagesChatBotRequest, APIError>> {

            typealias State = ResourceState<ChatBotResponse, NewMessagesChatBotRequest, APIError>

            return self
                .loadNewMessageStatesFromAPI(loadImpulseEmitter: self.loadImpulseEmitter.any)
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

    private func loadNewMessageStatesFromAPI(
        loadImpulseEmitter: AnyLoadImpulseEmitter<NewMessagesChatBotRequest>
        ) -> ValueStream<ResourceState<ChatBotResponse, NewMessagesChatBotRequest, APIError>> {

        typealias State = ResourceState<ChatBotResponse, NewMessagesChatBotRequest, APIError>

        return ValueStream
            <ResourceState<ChatBotResponse, NewMessagesChatBotRequest, APIError>> { sendState,
                disposable in

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

                    self.storage.loadNewMessage(completion: { response in
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
