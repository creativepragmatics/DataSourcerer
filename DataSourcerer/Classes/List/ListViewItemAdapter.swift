import Foundation

public struct ListViewItemAdapter<Item: Equatable, ProducedView: UIView, ContainingView: UIView> {
    public typealias PreferredViewWidth = CGFloat

    public let produceView: (Item, ContainingView, IndexPath) -> ProducedView
    public let registerAtContainingView: (ContainingView) -> Void
    public let itemViewSize: ((Item, ContainingView) -> CGSize)?

    init(produceView: @escaping (Item, ContainingView, IndexPath) -> ProducedView,
         registerAtContainingView: @escaping (ContainingView) -> Void,
         itemViewSize: ((Item, ContainingView) -> CGSize)? = nil) {
        self.produceView = produceView
        self.registerAtContainingView = registerAtContainingView
        self.itemViewSize = itemViewSize
    }
}

public extension ListViewItemAdapter {

    init<ViewProducer: ListItemViewProducer>(simpleWithViewProducer viewProducer: ViewProducer)
        where ViewProducer.Item == Item, ViewProducer.ContainingView == ContainingView,
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

    static var noSupplementaryTableViewAdapter: ListViewItemAdapter
        <NoSupplementaryItem, UIView, UITableView> {

        return ListViewItemAdapter<NoSupplementaryItem, UIView, UITableView>(
            produceView: { _, _, _ in UIView() },
            registerAtContainingView: { _ in }
        )
    }

    func idiomatic<ViewProducer: ListItemViewProducer>(
        loadingViewProducer: ViewProducer,
        errorViewProducer: ViewProducer,
        noResultsViewProducer: ViewProducer)
        -> ListViewItemAdapter<IdiomaticListItem<Item>, ProducedView, ContainingView>
        where ViewProducer.Item == IdiomaticListItem<Item>,
        ViewProducer.ContainingView == ContainingView,
        ViewProducer.ProducedView == ProducedView {

            return ListViewItemAdapter<IdiomaticListItem<Item>, ProducedView, ContainingView>(
                produceView: { item, containingView, indexPath -> ProducedView in
                    switch item {
                    case let .datasourceItem(datasourceItem):
                        return self.produceView(datasourceItem, containingView, indexPath)
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
