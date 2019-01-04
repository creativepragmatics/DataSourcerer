import DataSourcerer
import Foundation
import UIKit

class PublicReposRootViewController : UIViewController {

    lazy var viewModel: PublicReposViewModel = {
        PublicReposViewModel()
    }()

    private let disposeBag = DisposeBag()

    lazy var tableViewDatasource: DefaultSingleSectionTableViewDatasource = {
        return DefaultSingleSectionTableViewDatasource(statesObservable: viewModel.states.any,
                                                       cellType: PublicReposCell.self)
    }()

    lazy var tableViewController: DefaultSingleSectionTableViewController
        <PublicReposResponseContainer, VoidParameters, APIError, PublicReposCell> = {
        return DefaultSingleSectionTableViewController(tableViewDatasource: self.tableViewDatasource)
    }()

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

        tableViewDatasource
            .configure { configure in
                return configure
                    .valueToItems({ publicReposResponseContainer -> [PublicReposCell]? in
                        return publicReposResponseContainer.map({ PublicReposCell.repo($0) })
                    })
                    .itemToView({ viewType -> DefaultTableViewCellProducer<PublicReposCell> in
                        switch viewType {
                        case .repo:
                            return DefaultTableViewCellProducer.instantiate({ cell -> UITableViewCell in
                                switch cell {
                                case .loading, .noResults, .error: return UITableViewCell()
                                case let .repo(repo):
                                    let cell = UITableViewCell()
                                    cell.textLabel?.text = repo.full_name
                                    return cell
                                }
                            })
                        case .loading:
                            return .instantiate({ _ in return LoadingCell() })
                        case .error:
                            return .instantiate({ cell in
                                guard case let .error(error) = cell else { return ErrorTableViewCell() }
                                let tableViewCell = ErrorTableViewCell()
                                tableViewCell.content = error.errorMessage
                                return tableViewCell
                            })
                        case .noResults:
                            return .instantiate({ _ in
                                let tableViewCell = ErrorTableViewCell()
                                tableViewCell.content = StateErrorMessage
                                    .message("Strangely, there are no public repos on Github.")
                                return tableViewCell
                            })
                        }
                    })
                    .itemSelected({ [weak self] cell in
                        guard case let .repo(repo) = cell else { return }
                        self?.repoSelected(repo: repo)
                    })

            }

        addTableViewToHierarchy()

        tableViewDatasource.registerItemViews(with: tableViewController.tableView)

        tableViewController.onPullToRefresh = { [weak self] in
            self?.viewModel.refresh()
            self?.tableViewController.refreshControl?.beginRefreshing()
        }

        setupObservers()
    }

    private func addTableViewToHierarchy() {
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
    }

    private func setupObservers() {

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        viewModel.loadImpulseEmitter.timerMode = .none
    }

    func repoSelected(repo: PublicRepo) {
        print("Repo selected")
    }

}
