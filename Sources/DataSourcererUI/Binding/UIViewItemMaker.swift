import DataSourcerer
import Foundation
import UIKit

public extension Resource.ListBinding {
    struct UIViewItemMaker {
        public typealias UpdateView = (
            ItemModelType,
            View,
            ContainerView,
            IndexPath,
            _ isFirstUpdate: Bool
        ) -> Void
        public let makeView: (ItemModelType, ContainerView, IndexPath) -> View
        public let updateView: (
            ItemModelType,
            View,
            ContainerView,
            IndexPath,
            _ isFirstUpdate: Bool
        ) -> Void
        public let registerAtContainerView: (ContainerView) -> Void

        public init(
            makeView: @escaping (ItemModelType, ContainerView, IndexPath) -> View,
            updateView: @escaping UpdateView,
            registerAtContainerView: @escaping (ContainerView) -> Void
        ) {
            self.makeView = makeView
            self.updateView = updateView
            self.registerAtContainerView = registerAtContainerView
        }

        public func produceAndUpdateView(
            itemModel: ItemModelType,
            containingView: ContainerView,
            indexPath: IndexPath
        ) -> View {
            let view = makeView(itemModel, containingView, indexPath)
            updateView(itemModel, view, containingView, indexPath, true)
            return view
        }
    }
}

public protocol MultiViewTypeItemModel: ItemModel {
    associatedtype ItemViewType: CaseIterable, Hashable

    var itemViewType: ItemViewType { get }
}

public extension Resource.ListBinding.UIViewItemMaker
where View == UITableViewCell, ContainerView == UITableView {
    static func tableViewCellWithClass(
        _ `class`: View.Type,
        reuseIdentifier: String = UUID().uuidString,
        updateView: @escaping UpdateView = { _, _, _, _, _ in }
    ) -> Self {
        Self.init(
            makeView: { itemModel, tableView, indexPath -> UITableViewCell in
                return tableView.dequeueReusableCell(
                    withIdentifier: reuseIdentifier,
                    for: indexPath
                )
            },
            updateView: updateView,
            registerAtContainerView: { tableView in
                tableView.register(`class`, forCellReuseIdentifier: reuseIdentifier)
            }
        )
    }

    static func tableViewCellWithNib(
        _ nib: UINib,
        reuseIdentifier: String = UUID().uuidString,
        updateView: @escaping UpdateView
    ) -> Self {
        Self.init(
            makeView: { itemModel, tableView, indexPath -> UITableViewCell in
                let tableViewCell = tableView.dequeueReusableCell(
                    withIdentifier: reuseIdentifier,
                    for: indexPath
                )
                return tableViewCell
            },
            updateView: updateView,
            registerAtContainerView: { tableView in
                tableView.register(nib, forCellReuseIdentifier: reuseIdentifier)
            }
        )
    }

    static func tableViewCellWithoutReuse(
        create: @escaping (ItemModelType, UITableView, IndexPath) -> UITableViewCell,
        configureView: @escaping UpdateView
    ) -> Self {
        Self.init(
            makeView: { itemModel, tableView, indexPath -> UITableViewCell in
                return create(itemModel, tableView, indexPath)
            },
            updateView: configureView,
            registerAtContainerView: { _ in }
        )
    }
}
