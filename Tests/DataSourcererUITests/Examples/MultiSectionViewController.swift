import DataSourcererUI
import ReactiveCocoa
import ReactiveSwift
import UIKit

class MultiSectionViewController: UIViewController {
    let viewModel = MultiSectionViewModel()

    @IBOutlet var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        Lifetime.of(self) += viewModel.listBinding.bind(to: tableView, addRefreshControl: true)
        Lifetime.of(self) += viewModel.listBinding.didSelectItem.output.observeValues { selection in
            print("!!! Did select: \(selection)")
            selection.containingView.deselectRow(at: selection.indexPath, animated: true)
        }
    }
}

