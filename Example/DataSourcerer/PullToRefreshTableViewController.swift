import DataSourcerer
import Foundation
import UIKit

class PullToRefreshTableViewController : UIViewController {

    lazy var viewModel: PullToRefreshTableViewModel = {
        PullToRefreshTableViewModel()
    }()

    lazy var watchdog = Watchdog(threshold: 0.1, strictMode: false)

    private let disposeBag = DisposeBag()

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

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "TableView with Pull to Refresh"

        tableView.sourcerer
            .prepareBindingToDatasource(
                self.viewModel.datasource,
                baseItemModelType: PublicRepoCell.self,
                sectionModelType: SingleSection.self
            )
            .singleSection { response, _ -> [PublicRepoCell] in
                response.map { PublicRepoCell.repo($0) }
            }
            .cellsWithClass(
                UITableViewCell.self,
                configure: { repo, cellView, _, _ in
                    cellView.textLabel?.text = {
                        switch repo {
                        case let .repo(repo): return repo.name
                        case .error: return nil
                        }
                    }()
                }
            )
            .showLoadingAndErrors(
                configuration: ShowLoadingAndErrorsConfiguration(
                    errorsConfiguration: .ignoreErrorIfCachedValueAvailable
                ),
                loadingViewProducer: .tableViewCellWithoutReuse(
                    create: { (cell: IdiomaticItemModel<PublicRepoCell>, tableView: UITableView, indexPath: IndexPath)
                        -> UITableViewCell in
                        return LoadingCell(frame: .zero)
                    }
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
            .tweak { configuration in
                configuration.didSelectItem = { itemSelection in
                    print("Item selected: \(type(of: itemSelection.itemModel))")
                }
            }
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
