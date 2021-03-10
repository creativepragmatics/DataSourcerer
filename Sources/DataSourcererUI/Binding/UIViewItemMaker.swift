import DataSourcerer
import Foundation
import UIKit

public extension Resource.ListBinding {
    struct UIViewItemMaker {
        public typealias ConfigureView = (ItemModelType, View, ContainerView, IndexPath)
            -> Void
        public let makeView: (ItemModelType, ContainerView, IndexPath) -> View
        public let configureView: (ItemModelType, View, ContainerView, IndexPath) -> Void
        public let registerAtContainerView: (ContainerView) -> Void

        public init(
            makeView: @escaping (ItemModelType, ContainerView, IndexPath) -> View,
            configureView: @escaping ConfigureView,
            registerAtContainerView: @escaping (ContainerView) -> Void
        ) {
            self.makeView = makeView
            self.configureView = configureView
            self.registerAtContainerView = registerAtContainerView
        }

        public func produceAndConfigureView(
            itemModel: ItemModelType,
            containingView: ContainerView,
            indexPath: IndexPath
        ) -> View {
            let view = makeView(itemModel, containingView, indexPath)
            configureView(itemModel, view, containingView, indexPath)
            return view
        }
    }
}

public protocol MultiViewTypeItemModel: ItemModel {
    associatedtype ItemViewType: CaseIterable, Hashable

    var itemViewType: ItemViewType { get }
}

public extension Resource.ListBinding.UIViewItemMaker
where ItemModelType: MultiViewTypeItemModel {
    init(
        makeItemViewMaker: @escaping (ItemModelType.ItemViewType) -> Self
    ) {
        var viewMakersCache: [ItemModelType.ItemViewType: Self] = [:]
        func cachedViewMaker(_ viewType: ItemModelType.ItemViewType) -> Self {
            if let producer = viewMakersCache[viewType] {
                return producer
            } else {
                let producer = makeItemViewMaker(viewType)
                viewMakersCache[viewType] = producer
                return producer
            }
        }

        self.makeView = { itemModel, containingView, indexPath -> View in
            return cachedViewMaker(itemModel.itemViewType)
                .makeView(itemModel, containingView, indexPath)
        }

        self.configureView = { itemModel, View, containingView, indexPath in
            cachedViewMaker(itemModel.itemViewType)
                .configureView(itemModel, View, containingView, indexPath)
        }

        self.registerAtContainerView = { containingView in
            ItemModelType.ItemViewType.allCases.forEach {
                let viewProducer = cachedViewMaker($0)
                viewProducer.registerAtContainerView(containingView)
            }
        }
    }
}

public extension Resource.ListBinding.UIViewItemMaker
where View == UITableViewCell, ContainerView == UITableView {
    static func tableViewCellWithClass(
        _ `class`: View.Type,
        reuseIdentifier: String = UUID().uuidString,
        configureView: @escaping ConfigureView = { _, _, _, _ in }
    ) -> Self {
        Self.init(
            makeView: { itemModel, tableView, indexPath -> UITableViewCell in
                return tableView.dequeueReusableCell(
                    withIdentifier: reuseIdentifier,
                    for: indexPath
                )
            },
            configureView: configureView,
            registerAtContainerView: { tableView in
                tableView.register(`class`, forCellReuseIdentifier: reuseIdentifier)
            }
        )
    }

    static func tableViewCellWithNib(
        _ nib: UINib,
        reuseIdentifier: String = UUID().uuidString,
        configureView: @escaping ConfigureView
    ) -> Self {
        Self.init(
            makeView: { itemModel, tableView, indexPath -> UITableViewCell in
                let tableViewCell = tableView.dequeueReusableCell(
                    withIdentifier: reuseIdentifier,
                    for: indexPath
                )
                return tableViewCell
            },
            configureView: configureView,
            registerAtContainerView: { tableView in
                tableView.register(nib, forCellReuseIdentifier: reuseIdentifier)
            }
        )
    }

    static func tableViewCellWithoutReuse(
        create: @escaping (ItemModelType, UITableView, IndexPath) -> UITableViewCell,
        configureView: @escaping ConfigureView
    ) -> Self {
        Self.init(
            makeView: { itemModel, tableView, indexPath -> UITableViewCell in
                return create(itemModel, tableView, indexPath)
            },
            configureView: configureView,
            registerAtContainerView: { _ in }
        )
    }
}
