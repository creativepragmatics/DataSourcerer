import Foundation
import DataSourcerer

struct ChatBotTableItemModelsProducer {

    func make()
        -> ItemModelsProducer<ChatBotResponse, ChatBotRequest, APIError, ChatBotCell, NoSection> {

            return ItemModelsProducer(
                stateToListViewState: { state, valueToListViewStateTransformer
                    -> ListViewState<ChatBotRequest, ChatBotCell, NoSection> in

                    // In most cases we just return the generated ListViewState.
                    // But if the list is loading old messags, we need to show
                    // a loading cell at the top additionally.
                    if let value = state.value?.value, let loadImpulse = state.loadImpulse {
                        let listViewState = valueToListViewStateTransformer
                            .valueToListViewState(value, loadImpulse)

                        switch state.provisioningState {
                        case .notReady:
                            return .notReady
                        case .loading, .result:
                            return self.addOldMessageLoadingToTop(listViewState)
                        }
                    } else {
                        return .notReady
                    }
                },
                valueToListViewStateTransformer: valueToListViewStateTransformer()
            )
    }

    private func addOldMessageLoadingToTop(
        _ listViewState: ListViewState<ChatBotRequest, ChatBotCell, NoSection>
        ) -> ListViewState<ChatBotRequest, ChatBotCell, NoSection> {
        switch listViewState {
        case .notReady:
            return listViewState
        case let .readyToDisplay(loadImpulse, sectionsAndItems):
            guard let firstSectionAndItems = sectionsAndItems.first else {
                return listViewState
            }
            let loadingItem = ChatBotCell.oldMessagesLoading
            let newSectionAndItems = SectionAndItems(
                firstSectionAndItems.section,
                [loadingItem] + firstSectionAndItems.items
            )
            return ListViewState<ChatBotRequest, ChatBotCell, NoSection>
                .readyToDisplay(loadImpulse, [newSectionAndItems])
        }
    }

    private func valueToListViewStateTransformer()
        -> ValueToListViewStateTransformer
        <ChatBotResponse, ChatBotRequest, ChatBotCell, NoSection> {
            return ValueToListViewStateTransformer { value, loadImpulse
                -> ListViewState<ChatBotRequest, ChatBotCell, NoSection> in

                let cells = value.messages.map { ChatBotCell.message($0) }
                let sectionAndItems = SectionAndItems(NoSection(), cells)
                return ListViewState.readyToDisplay(loadImpulse, [sectionAndItems])
            }
    }
}

