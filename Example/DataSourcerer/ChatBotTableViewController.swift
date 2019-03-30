import DataSourcerer
import Foundation
import UIKit

class ChatBotTableViewController : UIViewController {

    lazy var viewModel: ChatBotTableViewModel = {
        ChatBotTableViewModel()
    }()

    lazy var watchdog = Watchdog(threshold: 0.1, strictMode: false)

    private let disposeBag = DisposeBag()

    private lazy var tableViewController =
        ListViewDatasourceConfiguration
            .buildSingleSectionTableView(
                datasource: viewModel.datasource,
                withCellModelType: PublicRepoCell.self
            )
            .mapSingleSectionItemModels { response -> [PublicRepoCell] in
                return response.map { PublicRepoCell.repo($0) }
            }
            .renderWithCellClass(
                cellType: UITableViewCell.self,
                dequeueIdentifier: "cell",
                configure: { repo, cellView in
                    cellView.textLabel?.text = {
                        switch repo {
                        case let .repo(repo): return repo.name
                        case .error: return nil
                        }
                    }()
                }
            )
            .configurationForFurtherCustomization
            .onDidSelectItem { [weak self] itemSelection in
                itemSelection.containingView.deselectRow(at: itemSelection.indexPath, animated: true)
                switch itemSelection.itemModel {
                case let .repo(repo):
                    self?.repoSelected(repo: repo)
                case .error:
                    return
                }
            }
            .showLoadingAndErrorStates(
                noResultsText: "No results",
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
                        .message("Strangely, there are no public repos on Github.")
                    return tableViewCell
                }
            )
            .singleSectionTableViewController
            .onPullToRefresh { [weak self] in
                self?.viewModel.datasource.refresh(type: LoadImpulseType(mode: .fullRefresh, issuer: .user))
                self?.tableViewController.refreshControl?.beginRefreshing()
            }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Chatbot TableView"

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

        // Hide pull to refresh when loading finishes
        tableViewController.refreshControl?.sourcerer
            .endRefreshingOnLoadingEnded(viewModel.datasource)
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewModel.loadImpulseEmitter.timerMode = .timeInterval(.seconds(90))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        _ = watchdog // init
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        viewModel.loadImpulseEmitter.timerMode = .none
    }

    func repoSelected(repo: PublicRepo) {
        print("Repo selected")
    }

}
