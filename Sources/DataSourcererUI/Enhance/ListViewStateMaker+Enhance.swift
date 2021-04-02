import DataSourcerer
import DifferenceKit
import Foundation
import ReactiveSwift

public extension Resource.ListBinding.ListViewStateMaker {
    typealias EnhancedListBinding = Resource.ListBinding<
        EnhancedItemModel<ItemModelType>,
        SectionModelType,
        View,
        ContainerView
    >
    typealias EnhancedListViewStateMaker = EnhancedListBinding.ListViewStateMaker
    typealias EnhancedDiffableSection = ArraySection<SectionModelType, EnhancedItemModel<ItemModelType>>
    typealias EnhancedSectionMaker = (Resource.State) -> EnhancedDiffableSection
    typealias EnhancedFailureSectionMaker = (Resource.FailureType) -> EnhancedDiffableSection

    func enhance(
        errorsConfiguration: EnhancedListViewStateErrorsConfiguration,
        loadingSection: Property<EnhancedSectionMaker?>,
        errorSection: Property<EnhancedFailureSectionMaker?>,
        noResultsSection: Property<EnhancedSectionMaker?>
    ) -> EnhancedListViewStateMaker {
        EnhancedListViewStateMaker(
            makeListViewState: { state, makeListViewStateFromResourceValue in
                Resource.ListBinding.ListViewState.enhance(
                    state: state,
                    errorsConfiguration: errorsConfiguration,
                    makeEnhancedListViewStateFromResourceValue: makeListViewStateFromResourceValue,
                    loadingSection: loadingSection,
                    errorSection: errorSection,
                    noResultsSection: noResultsSection
                )
            },
            makeListViewStateFromResourceValue: makeListViewStateFromResourceValue.enhance()
        )
    }
}
