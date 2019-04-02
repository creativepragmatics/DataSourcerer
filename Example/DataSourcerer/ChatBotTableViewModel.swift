import DataSourcerer
import Foundation

class ChatBotTableViewModel {

    typealias State = ResourceState<ChatBotResponse, ChatBotRequest, APIError>

    lazy var datasource: Datasource<ChatBotResponse, ChatBotRequest, APIError> = {

        let initialParams = ChatBotRequest.loadInitialMessages(limit: 20)
        let initialImpulse = LoadImpulse(params: initialParams, type: .initial)
        let loadImpulseEmitter = SimpleLoadImpulseEmitter(initialImpulse: initialImpulse).any

        let resourceStates = ChatBotResourceStatesProvider().resourceStates(
            loadImpulseEmitter: loadImpulseEmitter
        )

        let cachedStates = Datasource.CacheBehavior.none
            .apply(on: resourceStates, loadImpulseEmitter: loadImpulseEmitter)
            .skipRepeats()
            .observeOnUIThread()

        let shareableCachedState = cachedStates
            .shareable(initialValue: .notReady)

        return Datasource<ChatBotResponse, ChatBotRequest, APIError>(
            shareableCachedState,
            loadImpulseEmitter: loadImpulseEmitter
        )
    }()

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

    func tryLoadOldMessages(tableView: UITableView) {

        guard tableView.contentOffset.y < 100 else {
            return
        }

        switch datasource.state.value.provisioningState {
        case .loading, .notReady:
            return
        case .result:
            break // continue
        }

        let request = ChatBotRequest.loadOldMessages(oldestKnownMessageId: "mock value", limit: 20)
        let loadImpulse = LoadImpulse(
            params: request,
            type: LoadImpulseType(
                mode: .partialLoad, issuer: .user
            )
        )
        datasource.loadImpulseEmitter.emit(loadImpulse: loadImpulse, on: .current)
    }

}
