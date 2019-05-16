import DataSourcerer
import Foundation

class ChatBotTableViewModel {

    lazy var storage = ChatBotMockStorage()
    lazy var initialStates = InitialChatBotStates(storage: storage)
    lazy var newMessagesStates = NewMessagesChatBotStates(storage: storage)
    lazy var oldMessagesStates = OldMessagesChatBotStates(storage: storage)

    lazy var datasource: Datasource
        <PostInitialLoadChatBotState, InitialChatBotRequest, InitialChatBotError> = {

        let resourceStates = self.initialStates.states()
            .flatMapLatest { [weak self] initialLoadState -> AnyObservable<ChatBotResourceState> in
                guard let self = self else { return BroadcastObservable().any }

                let newMessages = self.newMessagesStates
                    .states()
                    .startWith(value: ResourceState.notReady)

                let oldMessages = self.oldMessagesStates
                    .states()
                    .startWith(value: ResourceState.notReady)

                return newMessages
                    .startWith(value: ResourceState.notReady)
                    .combine(with: oldMessages)
                    .map { newMessagesLoadState, oldMessagesLoadState -> ChatBotResourceState in

                        if let initialChatBotResponse = initialLoadState.value?.value {
                            let postInitialLoadState = PostInitialLoadChatBotState(
                                initialLoadResponse: initialChatBotResponse,
                                newMessagesState: newMessagesLoadState,
                                oldMessagesState: oldMessagesLoadState
                            )

                            return ChatBotResourceState(
                                provisioningState: initialLoadState.provisioningState,
                                loadImpulse: initialLoadState.loadImpulse,
                                value: EquatableBox(postInitialLoadState),
                                error: initialLoadState.error
                            )
                        } else {
                            return ChatBotResourceState(
                                provisioningState: initialLoadState.provisioningState,
                                loadImpulse: initialLoadState.loadImpulse,
                                value: nil,
                                error: initialLoadState.error
                            )
                        }
                    }
                    .startWith(
                        value: ChatBotResourceState(
                            provisioningState: initialLoadState.provisioningState,
                            loadImpulse: initialLoadState.loadImpulse,
                            value: (initialLoadState.value?.value).map {
                                EquatableBox(
                                    PostInitialLoadChatBotState(
                                        initialLoadResponse: $0,
                                        newMessagesState: .notReady,
                                        oldMessagesState: .notReady
                                    )
                                )
                            },
                            error: initialLoadState.error
                        )
                    )
        }

        let cachedStates = Datasource.CacheBehavior.none
            .apply(
                on: resourceStates,
                loadImpulseEmitter: initialStates.loadImpulseEmitter.any
            )
            .skipRepeats()
            .observeOnUIThread()

        let shareableCachedState = cachedStates
            .shareable(initialValue: .notReady)

        return Datasource<PostInitialLoadChatBotState, InitialChatBotRequest, InitialChatBotError>(
            shareableCachedState,
            loadImpulseEmitter: initialStates.loadImpulseEmitter.any
        )
    }()

    var newMessageTimer: Timer?

    func startReceivingNewMessages() {
        newMessageTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            guard let loadImpulseEmitter = self?.newMessagesStates.loadImpulseEmitter else { return }

            let loadImpulse = LoadImpulse(
                params: NewMessagesChatBotRequest(newestKnownMessageId: ""),
                type: LoadImpulseType(mode: LoadImpulseType.Mode.partialLoad, issuer: .system)
            )
            loadImpulseEmitter.emit(loadImpulse: loadImpulse, on: .current)
        })
    }

    func stopReceivingNewMessages() {
        newMessageTimer?.invalidate()
    }

    func tryLoadOldMessages(tableView: UITableView) {

        guard tableView.contentOffset.y < 100 else {
            return
        }

        guard let oldMessagesProvisioningState =
            datasource.state.value.value?.value.oldMessagesState.provisioningState else {
                return
        }

        switch oldMessagesProvisioningState {
        case .loading:
            return
        case .result, .notReady:
            break // continue
        }

        let request = OldMessagesChatBotRequest(oldestKnownMessageId: "mock value", limit: 20)
        let loadImpulse = LoadImpulse(
            params: request,
            type: LoadImpulseType(
                mode: .partialLoad, issuer: .user
            )
        )
        oldMessagesStates.loadImpulseEmitter.emit(loadImpulse: loadImpulse, on: .current)
    }

}

struct PostInitialLoadChatBotState: Equatable {
    let initialLoadResponse: InitialChatBotResponse
    let newMessagesState: ResourceState<ChatBotResponse, NewMessagesChatBotRequest, APIError>
    let oldMessagesState: ResourceState<ChatBotResponse, OldMessagesChatBotRequest, APIError>
}

typealias InitialChatBotResponse = ChatBotResponse // for better clarity

typealias InitialChatBotError = APIError // for better clarity

typealias ChatBotResourceState = ResourceState
    <PostInitialLoadChatBotState, InitialChatBotRequest, InitialChatBotError>

//typealias ChatBotListViewState = SingleSectionListViewState
//    <PostInitialLoadChatBotState, InitialChatBotRequest, APIError, IdiomaticItemModel<ChatBotCell>>
