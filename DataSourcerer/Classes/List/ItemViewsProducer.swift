import Foundation

public struct ItemViewsProducer<ItemModelType: Equatable, ProducedView: UIView, ContainingView: UIView> {
    public typealias PreferredViewWidth = CGFloat

    public let produceView: (ItemModelType, ContainingView, IndexPath) -> ProducedView
    public let registerAtContainingView: (ContainingView) -> Void
    public let itemViewSize: ((ItemModelType, ContainingView) -> CGSize)?

    public init(produceView: @escaping (ItemModelType, ContainingView, IndexPath) -> ProducedView,
         registerAtContainingView: @escaping (ContainingView) -> Void,
         itemViewSize: ((ItemModelType, ContainingView) -> CGSize)? = nil) {
        self.produceView = produceView
        self.registerAtContainingView = registerAtContainingView
        self.itemViewSize = itemViewSize
    }
}

public protocol MultiViewTypeItemModel: ItemModel {
    associatedtype ItemViewType: CaseIterable

    var itemViewType: ItemViewType { get }
}

public extension ItemViewsProducer where ItemModelType: MultiViewTypeItemModel {

    init<ViewProducer: ItemViewProducer>(
        viewProducerForViewType: @escaping (ItemModelType.ItemViewType) -> ViewProducer,
        itemViewSize: ((ItemModelType, ContainingView) -> CGSize)? = nil
        ) where ViewProducer.ContainingView == ContainingView,
        ViewProducer.ItemModelType == ItemModelType,
        ViewProducer.ProducedView == ProducedView {

        self.produceView = { itemModel, containingView, indexPath -> ProducedView in
            let viewProducer = viewProducerForViewType(itemModel.itemViewType)
            return viewProducer.view(containingView: containingView, item: itemModel, for: indexPath)
        }
        self.registerAtContainingView = { containingView in
            ItemModelType.ItemViewType.allCases.forEach {
                let viewProducer = viewProducerForViewType($0)
                viewProducer.register(at: containingView)
            }
        }
        self.itemViewSize = itemViewSize
    }
}

public extension ItemViewsProducer {

    init<ViewProducer: ItemViewProducer>(simpleWithViewProducer viewProducer: ViewProducer)
        where ViewProducer.ItemModelType == ItemModelType, ViewProducer.ContainingView == ContainingView,
        ViewProducer.ProducedView == ProducedView {

        self.init(
            produceView: { item, containingView, indexPath -> ProducedView in
                return viewProducer.view(containingView: containingView, item: item, for: indexPath)
            },
            registerAtContainingView: { containingView in
                viewProducer.register(at: containingView)
            }
        )
    }

    static var noSupplementaryTableViewAdapter: ItemViewsProducer
        <NoSupplementaryItemModel, UIView, UITableView> {

        return ItemViewsProducer<NoSupplementaryItemModel, UIView, UITableView>(
            produceView: { _, _, _ in UIView() },
            registerAtContainingView: { _ in }
        )
    }

    func showLoadingAndErrorStates<ViewProducer: ItemViewProducer>(
        loadingViewProducer: ViewProducer,
        errorViewProducer: ViewProducer,
        noResultsViewProducer: ViewProducer)
        -> ItemViewsProducer<IdiomaticItemModel<ItemModelType>, ProducedView, ContainingView>
        where ViewProducer.ItemModelType == IdiomaticItemModel<ItemModelType>,
        ViewProducer.ContainingView == ContainingView,
        ViewProducer.ProducedView == ProducedView {

            return ItemViewsProducer<IdiomaticItemModel<ItemModelType>, ProducedView, ContainingView>(
                produceView: { item, containingView, indexPath -> ProducedView in
                    switch item {
                    case let .baseItem(baseItem):
                        return self.produceView(baseItem, containingView, indexPath)
                    case let .error(error):
                        return errorViewProducer.view(containingView: containingView,
                                                      item: .error(error),
                                                      for: indexPath)
                    case .loading:
                        return loadingViewProducer.view(containingView: containingView,
                                                        item: .loading,
                                                        for: indexPath)
                    case let .noResults(noResultsText):
                        return noResultsViewProducer.view(containingView: containingView,
                                                          item: .noResults(noResultsText),
                                                          for: indexPath)
                    }
                },
                registerAtContainingView: { containingView in
                    self.registerAtContainingView(containingView)
                    loadingViewProducer.register(at: containingView)
                    errorViewProducer.register(at: containingView)
                    noResultsViewProducer.register(at: containingView)
                }
            )
    }

}

extension ItemViewsProducer where ItemModelType == NoSupplementaryItemModel {

    static var noSupplementaryViewAdapter: ItemViewsProducer
        <NoSupplementaryItemModel, UIView, ContainingView> {

            return ItemViewsProducer<NoSupplementaryItemModel, UIView, ContainingView>(
                produceView: { _, _, _ in UIView() },
                registerAtContainingView: { _ in }
            )
    }
}

public typealias TableViewCellAdapter<Cell: ItemModel>
    = ItemViewsProducer<Cell, UITableViewCell, UITableView>

public extension TableViewCellAdapter {

    static func tableViewCell<Cell: ItemModel, CellView: UITableViewCell>(
        withCellClass `class`: CellView.Type,
        reuseIdentifier: String,
        configure: @escaping (Cell, UITableViewCell) -> Void
        ) -> TableViewCellAdapter<Cell> {

        return TableViewCellAdapter<Cell>(
            simpleWithViewProducer: SimpleTableViewCellProducer.classAndIdentifier(
                class: `class`,
                identifier: reuseIdentifier,
                configure: configure
            )
        )
    }

}
