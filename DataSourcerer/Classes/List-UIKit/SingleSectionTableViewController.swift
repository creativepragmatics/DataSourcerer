import Dwifft
import Foundation

open class SingleSectionTableViewController
<Value: Equatable, P: ResourceParams, E, Cell: ItemModel>: UIViewController
where Cell.E == E {

    public typealias ValuesObservable = AnyObservable<Value>
    public typealias Cells = SingleSectionListViewState<Cell>
    public typealias Configuration = ListViewDatasourceConfiguration
        <Value, P, E, Cell, UITableViewCell, NoSection, NoSupplementaryItemModel, UIView,
        NoSupplementaryItemModel, UIView, UITableView>

    open var refreshControl: UIRefreshControl?
    private let disposeBag = DisposeBag()

    public lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: self.tableViewStyle)
        self.view.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        view.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        let footerView = UIView(frame: .zero)
        view.tableFooterView = footerView

        return view
    }()

    public var addEmptyViewAboveTableView = true // To prevent tableview insets bugs in iOS10
    public var tableViewStyle = UITableView.Style.plain
    public var estimatedRowHeight: CGFloat = 75
    public var supportPullToRefresh = true
    public var animateTableViewUpdates = true
    public var onPullToRefresh: (() -> Void)?

    open var isViewVisible: Bool {
        return viewIfLoaded?.window != nil && view.alpha > 0.001
    }

    private let configuration: Configuration
    public lazy var tableViewDatasource = TableViewDatasource(configuration: configuration, tableView: tableView)

    private var tableViewDiffCalculator: SingleSectionTableViewDiffCalculator<Cell>?

    public init(configuration: Configuration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("Storyboards cannot be used with this class")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        extendedLayoutIncludesOpaqueBars = true

        if addEmptyViewAboveTableView {
            view.addSubview(UIView())
        }

        tableView.delegate = tableViewDatasource
        tableView.dataSource = tableViewDatasource
        tableView.tableFooterView = UIView(frame: .zero)

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = estimatedRowHeight

        if #available(iOS 11.0, *) {
            tableView.insetsContentViewsToSafeArea = true
        }

        if supportPullToRefresh {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
            tableView.addSubview(refreshControl)
            tableView.sendSubviewToBack(refreshControl)
            self.refreshControl = refreshControl
        }

        let cellsProperty = tableViewDatasource.cellsProperty
        var previousCells = cellsProperty.value

        // Update table with most current cells
        cellsProperty.observe({ [weak self] cells in
            self?.updateCells(previous: previousCells, next: cells)
            previousCells = cells
        }).disposed(by: disposeBag)
    }

    private func updateCells(previous: Cells, next: Cells) {
        switch previous {
        case let .readyToDisplay(previousCells) where isViewVisible && animateTableViewUpdates:
            if self.tableViewDiffCalculator == nil {
                // Use previous cells as initial values such that "next" cells are
                // inserted with animations
                self.tableViewDiffCalculator = self.createTableViewDiffCalculator(initial: previousCells)
            }
            self.tableViewDiffCalculator?.rows = next.items ?? []
        case .readyToDisplay, .notReady:
            // Animations disabled or view invisible - skip animations.
            self.tableViewDiffCalculator = nil
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }

    private func createTableViewDiffCalculator(initial: [Cell])
        -> SingleSectionTableViewDiffCalculator<Cell> {
        let calculator = SingleSectionTableViewDiffCalculator<Cell>(tableView: tableView,
                                                                    initialRows: initial)
        calculator.insertionAnimation = .fade
        calculator.deletionAnimation = .fade
        return calculator
    }

    @objc
    func pullToRefresh() {
        onPullToRefresh?()
    }

}
