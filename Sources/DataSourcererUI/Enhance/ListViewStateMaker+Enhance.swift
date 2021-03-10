import DataSourcerer
import Foundation

public extension Resource.ListBinding.ListViewStateMaker {
    typealias EnhancedListBinding = Resource.ListBinding<
        EnhancedItemModel<ItemModelType>,
        SectionModelType,
        View,
        ContainerView
    >
    typealias EnhancedListViewStateMaker = EnhancedListBinding.ListViewStateMaker

    func enhance(
        errorsConfiguration: EnhancedListViewStateErrorsConfiguration
    ) -> EnhancedListViewStateMaker {
        EnhancedListViewStateMaker(
            makeListViewState: { state, makeListViewStateFromResourceValue in
                Resource.ListBinding.ListViewState.enhance(
                    state: state,
                    errorsConfiguration: errorsConfiguration,
                    makeListViewStateFromResourceValue: makeListViewStateFromResourceValue
                )
            },
            makeListViewStateFromResourceValue: makeListViewStateFromResourceValue.enhance()
        )
    }
}
