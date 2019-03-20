import DataSourcerer
import Foundation
import UIKit

class PublicReposRootViewController : UIViewController {

    lazy var viewModel: PublicReposViewModel = {
        PublicReposViewModel()
    }()

    lazy var watchdog = Watchdog(threshold: 0.1, strictMode: false)

    private let disposeBag = DisposeBag()

    private lazy var tableViewDatasourceCore = TableViewDatasourceCore
        .base(
            datasource: self.viewModel.datasource,
            itemModelProducer: ItemModelsProducer
                <PublicReposResponse, VoidParameters, APIError, PublicRepoCell, NoSection>
                .withSingleSectionItems { response
                    -> [PublicRepoCell] in
                    return response.map { PublicRepoCell.repo($0) }
                },
            itemViewAdapter: TableViewCellAdapter<PublicRepoCell>.tableViewCell(
                withCellClass: UITableViewCell.self,
                reuseIdentifier: "cell", configure: { repo, cellView in
                    cellView.textLabel?.text = {
                        switch repo {
                        case let .repo(repo): return repo.name
                        case .error: return nil
                        }
                    }()
                }
            )
        )
        .idiomatic(
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

    private lazy var tableViewController = SingleSectionTableViewController(
        core: tableViewDatasourceCore
    )

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Storyboards not supported for PublicReposViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Github Public Repos"

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

        setupObservers()
    }

    private func setupObservers() {

        tableViewController.onPullToRefresh = { [weak self] in
            self?.viewModel.refresh()
            self?.tableViewController.refreshControl?.beginRefreshing()
        }

        viewModel.datasource.state
            .loadingEnded()
            .observeOnUIThread()
            .observe { [weak self] _ in
                self?.tableViewController.refreshControl?.endRefreshing()
            }
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
