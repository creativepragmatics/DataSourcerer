import DataSourcerer
import Foundation
import UIKit

class ChatBotTableViewController : UIViewController {

    private let loadOldMessagesEnabledState = ChatBotLoadOldMessagesEnabledState()

    lazy var viewModel: ChatBotTableViewModel = {
        ChatBotTableViewModel(loadOldMessagesEnabledState: loadOldMessagesEnabledState)
    }()

    lazy var watchdog = Watchdog(threshold: 0.1, strictMode: false)

    private let disposeBag = DisposeBag()
    private lazy var cellUpdateInterceptor = ChatBotTableCellUpdateInterceptor(
        loadOldMessagesEnabledState: loadOldMessagesEnabledState,
        tryLoadOldMessages: { [weak self] in self?.viewModel.tryLoadOldMessages() }
    )

    private lazy var tableViewController =
        ListViewDatasourceConfiguration
            .buildSingleSectionTableView(
                datasource: viewModel.datasource,
                withCellModelType: ChatBotCell.self
            )
            .setItemModelsProducer(
                ChatBotTableItemModelsProducer().make()
            )
            .setItemViewsProducer(
                ChatBotItemViewsProducer().make()
            )
            .configurationForFurtherCustomization
            .onWillDisplayItem { [weak self] _, _, indexPath in
                if indexPath.row == 3 {
                    self?.viewModel.tryLoadOldMessages()
                }
            }
            .showLoadingAndErrorStates(
                noResultsText: "You have received no messages so far.",
                loadingViewProducer: SimpleTableViewCellProducer.instantiate { _ in return LoadingCell() },
                errorViewProducer: SimpleTableViewCellProducer.instantiate { cell in
                    guard case let .error(error) = cell else { return ErrorTableViewCell() }
                    let tableViewCell = ErrorTableViewCell()
                    tableViewCell.content = error.errorMessage
                    return tableViewCell
                },
                noResultsViewProducer: SimpleTableViewCellProducer.instantiate { _ in
                    let tableViewCell = ErrorTableViewCell()
                    tableViewCell.content = StateErrorMessage
                        .message("You have received no messages so far.")
                    return tableViewCell
                }
            )
            .singleSectionTableViewController
            .onPullToRefresh { [weak self] in
                self?.viewModel.datasource.refresh(
                    params: ChatBotRequest.loadOldMessages(oldestKnownMessageId: "", limit: 20),
                    type: LoadImpulseType(mode: .fullRefresh, issuer: .user)
                )
                self?.tableViewController.refreshControl?.beginRefreshing()
            }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Chatbot TableView"
        tableViewController.supportPullToRefresh = false

        tableViewController.willMove(toParent: self)
        self.addChild(tableViewController)
        self.view.addSubview(tableViewController.view)

        let view = tableViewController.view!
        view.translatesAutoresizingMaskIntoConstraints = false
        view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        view.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true

        tableViewController.didMove(toParent: self)
        tableViewController.willChangeCellsInView = { [weak self] tableView, previous, next in
            self?.cellUpdateInterceptor.willChangeCells(
                tableView: tableView,
                previous: previous,
                next: next
            )
            return
        }

        tableViewController.didChangeCellsInView = { [weak self] tableView, previous, next in
            self?.cellUpdateInterceptor.didChangeCells(
                tableView: tableView,
                previous: previous,
                next: next
            )
            return
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewModel.startReceivingNewMessages()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        _ = watchdog // init
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        viewModel.stopReceivingNewMessages()
    }

    func repoSelected(repo: PublicRepo) {
        print("Repo selected")
    }

}
