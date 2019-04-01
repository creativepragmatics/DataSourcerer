import Foundation
import DataSourcerer

struct ChatBotItemViewsProducer {

    func make() -> ItemViewsProducer<ChatBotCell, UITableViewCell, UITableView> {

        return ItemViewsProducer(
            viewProducerForViewType: { viewType -> SimpleTableViewCellProducer<ChatBotCell> in
                switch viewType {
                case .message:
                    return SimpleTableViewCellProducer.classAndIdentifier(
                        class: UITableViewCell.self,
                        identifier: "cell",
                        configure: { cell, cellView in
                            cellView.textLabel?.text = {
                                switch cell {
                                case let .message(message): return message.message
                                case let .header(title): return title
                                case .error, .oldMessagesLoading: return nil
                                }
                            }()
                    }
                    )
                case .loadOldMessages:
                    return SimpleTableViewCellProducer.classAndIdentifier(
                        class: LoadingCell.self,
                        identifier: "loadingCell",
                        configure: { _, _ in

                    }
                    )
                }
            }
        )
    }
}
