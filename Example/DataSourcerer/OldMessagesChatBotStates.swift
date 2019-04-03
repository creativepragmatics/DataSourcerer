import Foundation
import DataSourcerer

struct OldMessagesChatBotStates {

    let storage: ChatBotMockStorage
    let loadImpulseEmitter = SimpleLoadImpulseEmitter<OldMessagesChatBotRequest>(
        initialImpulse: nil
    )

    init(storage: ChatBotMockStorage) {
        self.storage = storage
    }

    func states()
        -> AnyObservable<ResourceState<ChatBotResponse, OldMessagesChatBotRequest, APIError>> {

            typealias State = ResourceState<ChatBotResponse, OldMessagesChatBotRequest, APIError>

            return self.loadOldMessageStatesFromAPI(loadImpulseEmitter: self.loadImpulseEmitter.any)
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
                                    messages: nextResponse.messages + cumulativeResponse.messages,
                                    currentAvailableActions: cumulativeResponse.currentAvailableActions
                                )
                            ),
                            loadImpulse: loadImpulse,
                            fallbackError: next.error
                        )
                    }
            }
    }
    
    private func loadOldMessageStatesFromAPI(
        loadImpulseEmitter: AnyLoadImpulseEmitter<OldMessagesChatBotRequest>
    ) -> ValueStream<ResourceState<ChatBotResponse, OldMessagesChatBotRequest, APIError>> {

        typealias State = ResourceState<ChatBotResponse, OldMessagesChatBotRequest, APIError>

        return ValueStream
            <ResourceState<ChatBotResponse, OldMessagesChatBotRequest, APIError>> { sendState,
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

                    self.storage.loadMoreOldMessages(limit: loadImpulse.params.limit, completion: { response in
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
