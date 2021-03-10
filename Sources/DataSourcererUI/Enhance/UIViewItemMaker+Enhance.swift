import DataSourcerer
import Foundation

public extension Resource.ListBinding.UIViewItemMaker {
    typealias EnhancedUIViewItemMaker = Resource.ListBinding<
        EnhancedItemModel<ItemModelType>,
        SectionModelType,
        View,
        ContainerView
    >.UIViewItemMaker

    func enhance(
        loadingViewMaker: EnhancedUIViewItemMaker?,
        errorViewMaker: EnhancedUIViewItemMaker?,
        noResultsViewMaker: EnhancedUIViewItemMaker?
    ) -> EnhancedUIViewItemMaker {
        EnhancedUIViewItemMaker(
            makeView: { enhancedItem, containerView, indexPath -> View in
                switch enhancedItem {
                case let .baseItem(baseItem):
                    return self.makeView(baseItem, containerView, indexPath)
                case let .error(error):
                    guard let maker = errorViewMaker else {
                        assertionFailure("Received EnhancedItemModel.error, but no errorViewMaker")
                        return View()
                    }
                    return maker.makeView(
                        .error(error),
                        containerView,
                        indexPath
                    )
                case .loading:
                    guard let maker = loadingViewMaker else {
                        assertionFailure("Received EnhancedItemModel.loading, but no loadingViewMaker")
                        return View()
                    }
                    return maker.makeView(
                        .loading,
                        containerView,
                        indexPath
                    )
                case .noResults:
                    guard let maker = noResultsViewMaker else {
                        assertionFailure("Received EnhancedItemModel.noResults, but no noResultsViewMaker")
                        return View()
                    }
                    return maker.makeView(
                        .noResults,
                        containerView,
                        indexPath
                    )
                }
            },
            configureView: { enhancedItem, view, containerView, indexPath in
                switch enhancedItem {
                case let .baseItem(baseItem):
                    return self.configureView(baseItem, view, containerView, indexPath)
                case let .error(error):
                    guard let maker = errorViewMaker else {
                        assertionFailure("Received EnhancedItemModel.error, but no errorViewMaker")
                        return
                    }
                    return maker.configureView(
                        .error(error),
                        view,
                        containerView,
                        indexPath
                    )
                case .loading:
                    guard let maker = loadingViewMaker else {
                        assertionFailure("Received EnhancedItemModel.loading, but no loadingViewMaker")
                        return
                    }
                    return maker.configureView(
                        .loading,
                        view,
                        containerView,
                        indexPath
                    )
                case .noResults:
                    guard let maker = noResultsViewMaker else {
                        assertionFailure("Received EnhancedItemModel.noResults, but no noResultsViewMaker")
                        return
                    }
                    return maker.configureView(
                        .noResults,
                        view,
                        containerView,
                        indexPath
                    )
                }
            },
            registerAtContainerView: {
                self.registerAtContainerView($0)
                loadingViewMaker?.registerAtContainerView($0)
                errorViewMaker?.registerAtContainerView($0)
                noResultsViewMaker?.registerAtContainerView($0)
            }
        )
    }
}
