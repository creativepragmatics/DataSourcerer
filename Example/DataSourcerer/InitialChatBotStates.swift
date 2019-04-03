import Foundation
import DataSourcerer

struct InitialChatBotStates {

    let storage: ChatBotMockStorage
    let loadImpulseEmitter = SimpleLoadImpulseEmitter(
        initialImpulse: LoadImpulse(params: InitialChatBotRequest(limit: 20), type: .initial)
    )

    init(storage: ChatBotMockStorage) {
        self.storage = storage
    }

    func states()
        -> AnyObservable<ResourceState<InitialChatBotResponse, InitialChatBotRequest, InitialChatBotError>> {

            typealias State = ResourceState
                <InitialChatBotResponse, InitialChatBotRequest, InitialChatBotError>

            return ValueStream
                <ResourceState
                <InitialChatBotResponse, InitialChatBotRequest, InitialChatBotError>
                > { sendState, disposable in

                    disposable += self.loadImpulseEmitter.observe { loadImpulse in

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

                        self.storage.loadInitial(limit: loadImpulse.params.limit, completion: { response in
                            let state = State.value(
                                valueBox: EquatableBox(response),
                                loadImpulse: loadImpulse,
                                fallbackError: nil
                            )
                            sendState(state)
                        })
                    }
            }
            .rememberLatestSuccessAndError()
    }
}
