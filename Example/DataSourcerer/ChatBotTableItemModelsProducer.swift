import Foundation
import DataSourcerer

struct ChatBotTableItemModelsProducer {

    func make()
        -> ItemModelsProducer<ChatBotResponse, ChatBotRequest, APIError, ChatBotCell, NoSection> {

            return ItemModelsProducer(baseValueToListViewStateTransformer: valueToListViewStateTransformer())
    }

    private func valueToListViewStateTransformer()
        -> ValueToListViewStateTransformer
        <ChatBotResponse, ChatBotRequest, ChatBotCell, NoSection> {
            return ValueToListViewStateTransformer { value, loadImpulse, provisioningState
                -> ListViewState<ChatBotRequest, ChatBotCell, NoSection> in

                    switch provisioningState {
                    case .notReady:
                        return .notReady
                    case .loading, .result:
                        let cells = value.messages.map { ChatBotCell.message($0) }
                        let loadingItem = ChatBotCell.oldMessagesLoading
                        let sectionAndItems = SectionAndItems(NoSection(), [loadingItem] + cells)
                        return ListViewState.readyToDisplay(loadImpulse, provisioningState, [sectionAndItems])
                    }
            }
    }
}

