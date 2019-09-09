import DataSourcerer
import Foundation
import UIKit

class ChatBotTableViewController : UIViewController {

    let viewModel = ChatBotTableViewModel()

    lazy var watchdog = Watchdog(threshold: 0.1, strictMode: false)

    private let disposeBag = DisposeBag()
    private lazy var cellUpdateInterceptor = ChatBotTableCellUpdateInterceptor()
    private var loadOldMessagesTimer: Timer?

    private lazy var tableView: UITableView = {
        let view = UITableView()
        self.view.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        view.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true

        return view
    }()


//    private lazy var tableViewController =
//        ListViewDatasourceConfiguration
//            .buildSingleSectionTableView(
//                datasource: viewModel.datasource,
//                withCellModelType: ChatBotCell.self
//            )
//            .setItemModelsProducer(
//                ChatBotTableItemModelsProducer().make()
//            )
//            .setItemViewsProducer(
//                ChatBotItemViewsProducer().make()
//            )
//            .configurationForFurtherCustomization
//            .showLoadingAndErrorStates(
//                configuration: ShowLoadingAndErrorsConfiguration(
//                    errorsConfiguration: .ignoreErrorIfCachedValueAvailable
//                ),
//                noResultsText: "You have received no messages so far.",
//                loadingViewProducer: TableViewCellProducer.instantiate { _ in
//                    let loadingCell = LoadingCell()
//                    loadingCell.loadingIndicatorView.color = .white
//                    loadingCell.backgroundColor = .clear
//                    return loadingCell
//                },
//                errorViewProducer: TableViewCellProducer.instantiate { cell in
//                    guard case let .error(error) = cell else { return ErrorTableViewCell() }
//                    let tableViewCell = ErrorTableViewCell()
//                    tableViewCell.content = error.errorMessage
//                    return tableViewCell
//                },
//                noResultsViewProducer: TableViewCellProducer.instantiate { _ in
//                    let tableViewCell = ErrorTableViewCell()
//                    tableViewCell.content = StateErrorMessage
//                        .message("You have received no messages so far.")
//                    return tableViewCell
//                }
//            )
//            .singleSectionTableViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Chatbot TableView"

        tableView.sourcerer
            .prepareBindingToDatasource(
                self.viewModel.datasource,
                baseItemModelType: ChatBotCell.self,
                sectionModelType: SingleSection.self
            )
            .singleSection { state, _ -> [ChatBotCell] in
                let oldMessages = state.oldMessagesState.value?.value.messages ?? []
                let initialMessages = state.initialLoadResponse.messages
                let newMessages = state.newMessagesState.value?.value.messages ?? []
                let allMessages = oldMessages + initialMessages + newMessages
                return allMessages.map { ChatBotCell.message($0) }
            }
            .multipleCellTypes(
                createProducer: { viewType
                    -> ItemViewsProducer<ChatBotCell, UITableViewCell, UITableView> in
                    switch viewType {
                    case .message:
                        return .tableViewCellWithClass(
                            ChatBotIncomingMessageTableViewCell.self,
                            configureView: { cell, cellView, tableView, indexPath in
                                (cellView as? ChatBotIncomingMessageTableViewCell)?.messageLabel.text = {
                                    switch cell {
                                    case let .message(message): return message.message
                                    case let .header(title): return title
                                    case .error, .oldMessagesLoading: return nil
                                    }
                                }()
                            }
                        )
                    case .loadOldMessages:
                        return .tableViewCellWithClass(
                            LoadingCell.self,
                            configureView: { _, _, _, _ in }
                        )
                    }
                }
            )
            .showLoadingAndErrors(
                configuration: ShowLoadingAndErrorsConfiguration(
                    errorsConfiguration: .ignoreErrorIfCachedValueAvailable
                ),
                loadingViewProducer: .tableViewCellWithoutReuse(
                    create: { _, _, _ in return LoadingCell(frame: .zero) }
                ),
                errorViewProducer: .tableViewCellWithoutReuse(
                    create: { _, _, _ in
                        return ErrorTableViewCell()
                    },
                    configureView: { model, cell, _, _ in
                        guard case let .error(error) = model else { return }
                        (cell as? ErrorTableViewCell)?.content = error.errorMessage
                    }
                ),
                noResultsViewProducer: .tableViewCellWithoutReuse(
                    create: { _, _, _ in
                        return ErrorTableViewCell()
                    },
                    configureView: { model, cell, _, _ in
                        (cell as? ErrorTableViewCell)?.content = StateErrorMessage
                            .message("Strangely, there are no public repos on Github.")
                        return
                    }
                )
            )
            .bind()
//        tableViewController.supportPullToRefresh = false
//
//        tableViewController.willMove(toParent: self)
//        self.addChild(tableViewController)
//        self.view.addSubview(tableViewController.view)
//
//        let view = tableViewController.view!
//        view.translatesAutoresizingMaskIntoConstraints = false
//        view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
//        view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
//        view.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
//        view.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
//
//        tableViewController.didMove(toParent: self)
//        tableViewController.willChangeCellsInView = { [weak self] tableView, previous, next in
//            self?.cellUpdateInterceptor.willChangeCells(
//                tableView: tableView,
//                previous: previous,
//                next: next
//            )
//            return
//        }
//
//        tableViewController.didChangeCellsInView = { [weak self] tableView, previous, next in
//            self?.cellUpdateInterceptor.didChangeCells(
//                tableView: tableView,
//                previous: previous,
//                next: next
//            )
//            return
//        }
//
//        tableViewController.tableView.backgroundColor = UIColor(red: 0, green: 0.6, blue: 0.91, alpha: 1)
//        tableViewController.tableView.separatorStyle = .none
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewModel.startReceivingNewMessages()
        loadOldMessagesTimer?.invalidate()
        loadOldMessagesTimer = Timer.scheduledTimer(
            withTimeInterval: 0.3,
            repeats: true,
            block: { [weak self] _ in
                guard let tableView = self?.tableView else { return }
                self?.viewModel.tryLoadOldMessages(tableView: tableView)
            }
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        _ = watchdog // init
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        viewModel.stopReceivingNewMessages()
        loadOldMessagesTimer?.invalidate()
    }

    func repoSelected(repo: PublicRepo) {
        print("Repo selected")
    }

}
