import DataSourcerer
import Foundation
import UIKit

class PublicReposRootViewController : UIViewController {

    lazy var viewModel: PublicReposViewModel = {
        PublicReposViewModel()
    }()

    lazy var watchdog = Watchdog(threshold: 0.1, strictMode: false)

    private let disposeBag = DisposeBag()

    private lazy var datasourceCore = TableViewDatasourceCore<
    State<PublicReposViewModel.Value, PublicReposViewModel.P, PublicReposViewModel.E>,
    PublicRepoCell, UITableViewCell, NoSection, NoSupplementaryItem, UIView,
        NoSupplementaryItem, UIView
    >(
        simpleCoreWithValueAndSectionsProperty: self.viewModel.valueAndSections,
        itemViewAdapter: ListViewItemAdapter(
            simpleWithViewProducer: SimpleTableViewCellProducer.classAndIdentifier(
                class: UITableViewCell.self,
                identifier: "cell",
                configure: { repo, cell in
                    cell.textLabel?.text = {
                        switch repo {
                        case let .repo(repo): return repo.name
                        case .error: return nil
                        }
                    }()
                }
            )
        ),
        headerItemViewAdapter: .noSupplementaryTableViewAdapter,
        footerItemViewAdapter: .noSupplementaryTableViewAdapter
        )

    private lazy var idiomaticDatasourceCore = datasourceCore
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
        core: idiomaticDatasourceCore
    )

//    private lazy var tableViewController: TableViewController = {
//        let tableViewController = makeTableViewController()
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
//
//        return tableViewController
//    }()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Storyboards not supported for PublicReposViewController")
    }

//    private func makeTableViewController() -> TableViewController {
//
//
//        return TableViewController(statesObservable: viewModel.states.any) { configure in
//            configure
//                .valueToItems { publicReposResponseContainer -> [PublicReposCell]? in
//                    return publicReposResponseContainer.map({ PublicReposCell.repo($0) })
//                }
//                .idiomaticItemToView { viewType -> SimpleTableViewCellProducer<PublicReposCell> in
//                    switch viewType {
//                    case .repo:
//                        return SimpleTableViewCellProducer.instantiate { cell -> UITableViewCell in
//                            switch cell {
//                            case .loading, .noResults, .error: return UITableViewCell()
//                            case let .repo(repo):
//                                let cell = UITableViewCell()
//                                cell.textLabel?.text = repo.full_name
//                                return cell
//                            }
//                        }
//                    case .loading:
//                        return .instantiate { _ in return LoadingCell() }
//                    case .error:
//                        return .instantiate { cell in
//                            guard case let .error(error) = cell else { return ErrorTableViewCell() }
//                            let tableViewCell = ErrorTableViewCell()
//                            tableViewCell.content = error.errorMessage
//                            return tableViewCell
//                        }
//                    case .noResults:
//                        return .instantiate { _ in
//                            let tableViewCell = ErrorTableViewCell()
//                            tableViewCell.content = StateErrorMessage
//                                .message("Strangely, there are no public repos on Github.")
//                            return tableViewCell
//                        }
//                    }
//                }
//                .itemSelected { [weak self] cell in
//                    guard case let .repo(repo) = cell else { return }
//                    self?.repoSelected(repo: repo)
//                }
//        }
//    }

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

        viewModel.states
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
