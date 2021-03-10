import DataSourcerer
import Foundation
import ReactiveSwift

public extension Resource.ListBinding {
    typealias EnhancedListBinding = Resource.ListBinding<
        EnhancedItemModel<ItemModelType>,
        SectionModelType,
        View,
        ContainerView
    >
    typealias EnhancedUIViewItemMaker = EnhancedListBinding.UIViewItemMaker

    func enhance(
        errorsConfiguration: Property<EnhancedListViewStateErrorsConfiguration>,
        loadingViewMaker: Property<EnhancedUIViewItemMaker>?,
        errorViewMaker: Property<EnhancedUIViewItemMaker>?,
        noResultsViewMaker: Property<EnhancedUIViewItemMaker>?
    ) -> EnhancedListBinding {
        let enhancedListViewStateMaker = listViewStateMaker
            .combineLatest(with: errorsConfiguration)
            .map { listViewStateMaker, errorsConfiguration in
                listViewStateMaker.enhance(
                    errorsConfiguration: errorsConfiguration
                )
            }

        guard let enhancedViewMakers = Property<[EnhancedUIViewItemMaker?]>
            .combineLatest([
                loadingViewMaker.absorbOptional(),
                errorViewMaker.absorbOptional(),
                noResultsViewMaker.absorbOptional()
            ]) else {
            preconditionFailure("enhancedViewMakers must never be nil - please file a bug!")
        }

        let enhancedItemViewMaker = itemViewMaker
            .combineLatest(with: enhancedViewMakers)
            .map { itemViewMaker, enhancedViewMakers in
                itemViewMaker.enhance(
                    loadingViewMaker: enhancedViewMakers[0],
                    errorViewMaker: enhancedViewMakers[1],
                    noResultsViewMaker: enhancedViewMakers[2]
                )
            }

        return EnhancedListBinding(
            datasource: datasource,
            listViewStateMaker: enhancedListViewStateMaker,
            itemViewMaker: enhancedItemViewMaker,
            supplementaryViewMaker: supplementaryViewMaker.map { $0.enhance() }
        )
    }
}

private extension Optional {
    /// Transforms a `Property<Value>?` to a `Property<Value?>`.
    func absorbOptional<Value>() -> Property<Value?> where Wrapped == Property<Value> {
        map { $0.map { $0 } } ?? Property(value: nil)
    }
}
