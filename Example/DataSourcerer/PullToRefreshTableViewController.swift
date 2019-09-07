import DataSourcerer
import Foundation
import UIKit

class PullToRefreshTableViewController : UIViewController {

    lazy var viewModel: PullToRefreshTableViewModel = {
        PullToRefreshTableViewModel()
    }()

    lazy var watchdog = Watchdog(threshold: 0.1, strictMode: false)

    private let disposeBag = DisposeBag()

//    private var refreshControl: UIRefreshControl? {
//        return tableViewController.refreshControl
//    }

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
//                withCellModelType: PublicRepoCell.self
//            )
//            .mapSingleSectionItemModels { response, _ -> [PublicRepoCell] in
//                return response.map { PublicRepoCell.repo($0) }
//            }
//            .renderWithCellClass(
//                cellType: UITableViewCell.self,
//                dequeueIdentifier: "cell",
//                configure: { repo, cellView in
//                    cellView.textLabel?.text = {
//                        switch repo {
//                        case let .repo(repo): return repo.name
//                        case .error: return nil
//                        }
//                    }()
//                }
//            )
//            .configurationForFurtherCustomization
//            .onDidSelectItem { [weak self] itemSelection in
//                itemSelection.containingView.deselectRow(at: itemSelection.indexPath, animated: true)
//                switch itemSelection.itemModel {
//                case let .repo(repo):
//                    self?.repoSelected(repo: repo)
//                case .error:
//                    return
//                }
//            }
//            .showLoadingAndErrorStates(
//                configuration: ShowLoadingAndErrorsConfiguration(
//                    errorsConfiguration: .ignoreErrorIfCachedValueAvailable
//                ),
//                noResultsText: "No results",
//                loadingViewProducer: TableViewCellProducer.instantiate { _ in return LoadingCell() },
//                errorViewProducer: TableViewCellProducer.instantiate { cell in
//                    guard case let .error(error) = cell else { return ErrorTableViewCell() }
//                    let tableViewCell = ErrorTableViewCell()
//                    tableViewCell.content = error.errorMessage
//                    return tableViewCell
//                },
//                noResultsViewProducer: TableViewCellProducer.instantiate { _ in
//                    let tableViewCell = ErrorTableViewCell()
//                    tableViewCell.content = StateErrorMessage
//                        .message("Strangely, there are no public repos on Github.")
//                    return tableViewCell
//                }
//            )
//            .singleSectionTableViewController
//            .onPullToRefresh { [weak self] in
//                self?.viewModel.datasource.refresh(type: LoadImpulseType(mode: .fullRefresh, issuer: .user))
//                self?.refreshControl?.beginRefreshing()
//            }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "TableView with Pull to Refresh"

        let bindingSource = tableView.sourcerer
            .prepareBindingToDatasource(
                self.viewModel.datasource,
                baseItemModelType: PublicRepoCell.self,
                sectionModelType: SingleSection.self
            )
            .singleSection { response, _ -> [PublicRepoCell] in
                response.map { PublicRepoCell.repo($0) }
            }
            .cellsWithClass(UITableViewCell.self) { repo, cellView in
                cellView.textLabel?.text = {
                    switch repo {
                    case let .repo(repo): return repo.name
                    case .error: return nil
                    }
                }()
            }
            .showLoadingAndErrors(
                configuration: ShowLoadingAndErrorsConfiguration(
                    errorsConfiguration: .ignoreErrorIfCachedValueAvailable
                ),
                loadingViewProducer: TableViewCellProducer.instantiate { _ in return LoadingCell() },
                errorViewProducer: TableViewCellProducer.instantiate { cell in
                    guard case let .error(error) = cell else { return ErrorTableViewCell() }
                    let tableViewCell = ErrorTableViewCell()
                    tableViewCell.content = error.errorMessage
                    return tableViewCell
                },
                noResultsViewProducer: TableViewCellProducer.instantiate { _ in
                    let tableViewCell = ErrorTableViewCell()
                    tableViewCell.content = StateErrorMessage
                        .message("Strangely, there are no public repos on Github.")
                    return tableViewCell
                },
                noResultsText: "No results"
            )
            .bind()

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(onPullToRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        viewModel.datasource.state.observe { [weak refreshControl] state in
            switch state.provisioningState {
            case .notReady, .loading:
                break
            case .result:
                refreshControl?.endRefreshing()
            }
        }.disposed(by: self.disposeBag)
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

    @objc
    func onPullToRefresh() {
        viewModel.loadImpulseEmitter.emit(type: LoadImpulseType(mode: .fullRefresh, issuer: .user), on: .current)
    }

}
