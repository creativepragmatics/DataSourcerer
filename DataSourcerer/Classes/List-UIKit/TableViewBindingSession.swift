import Foundation
import Dwifft

public final class TableViewBindingSession
<Value, P: ResourceParams, E: ResourceError, CellModelType: ItemModel, SectionModelType: SectionModel> {

    public typealias TableViewStateAlias = ListViewState<Value, P, E, CellModelType, SectionModelType>
    public typealias TableViewUpdaterAlias = ListViewUpdater<Value, P, E, CellModelType, SectionModelType>

    public weak var tableView: UITableView?
    public let tableViewUpdater: TableViewUpdaterAlias
    private var disposeBag: DisposeBag?

    public init(
        tableView: UITableView,
        tableViewUpdater: TableViewUpdaterAlias,
        bindingDisposable: Disposable
    ) {
        self.tableView = tableView
        self.tableViewUpdater = tableViewUpdater

        let disposeBag = DisposeBag()
        disposeBag.add(bindingDisposable)
        self.disposeBag = disposeBag
    }
}
