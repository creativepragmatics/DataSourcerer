import Foundation

public final class TableViewBindingSession
<Value, P: ResourceParams, E: ResourceError, CellModelType: ItemModel, SectionModelType: SectionModel> {

    public typealias TableViewStateAlias = ListViewState<Value, P, E, CellModelType, SectionModelType>

    public weak var tableView: UITableView?
    private var disposeBag: DisposeBag?

    public init(
        tableView: UITableView,
        bindingDisposable: Disposable
    ) {
        self.tableView = tableView

        let disposeBag = DisposeBag()
        disposeBag.add(bindingDisposable)
        self.disposeBag = disposeBag
    }
}
