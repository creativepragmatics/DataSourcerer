import DataSourcerer
import DifferenceKit
import Foundation
import ReactiveSwift
import UIKit

public extension Resource.ListBinding.ListViewState {
    typealias EnhancedListBinding = Resource.ListBinding<
        EnhancedItemModel<ItemModelType>,
        SectionModelType,
        View,
        ContainerView
    >
    typealias EnhancedDiffableSection = ArraySection<SectionModelType, EnhancedItemModel<ItemModelType>>
    typealias EnhancedSectionMaker = (Resource.State) -> EnhancedDiffableSection
    typealias EnhancedFailureSectionMaker = (Resource.FailureType) -> EnhancedDiffableSection

    static func enhance(
        state: Resource.State,
        errorsConfiguration: EnhancedListViewStateErrorsConfiguration,
        makeEnhancedListViewStateFromResourceValue: EnhancedListBinding.MakeListViewStateFromResourceValue,
        loadingSection: Property<EnhancedSectionMaker?>,
        errorSection: Property<EnhancedFailureSectionMaker?>,
        noResultsSection: Property<EnhancedSectionMaker?>
    ) -> Resource.ListBinding<EnhancedItemModel<ItemModelType>,
                              SectionModelType,
                              View,
                              ContainerView>.ListViewState {
        typealias EnhancedListViewState = Resource.ListBinding<
            EnhancedItemModel<ItemModelType>,
            SectionModelType,
            View,
            ContainerView
        >.ListViewState
        typealias EnhancedSection = ArraySection<
            SectionModelType,
            EnhancedItemModel<ItemModelType>
        >

        guard state.loadImpulse != nil else {
            return .notReady
        }

        func boxedValueToSections(_ box: EquatableBox<Value>?) -> [EnhancedSection]? {
            (box?.value)
                .flatMap { value -> [EnhancedSection]? in
                    makeEnhancedListViewStateFromResourceValue.makeListViewState(
                        value,
                        state
                    ).sections
                }
        }

        func numberOfItems(_ sections: [EnhancedSection]) -> Int {
            sections.map({ $0.elements.count }).reduce(0, +)
        }

        var loading: EnhancedListViewState? {
            loadingSection.value.map {
                .readyToDisplay(
                    state,
                    [$0(state)]
                )
            }
        }

        var noResults: EnhancedListViewState? {
            noResultsSection.value.map {
                .readyToDisplay(
                    state,
                    [$0(state)]
                )
            }
        }

        var empty: EnhancedListViewState {
            .readyToDisplay(
                state,
                [EnhancedSection(model: SectionModelType(), elements: [])]
            )
        }

        let showError: ((Resource.FailureType) -> EnhancedListViewState)? =
            errorSection.value.map { maker -> ((Resource.FailureType) -> EnhancedListViewState) in
                { error in
                    .readyToDisplay(
                        state,
                        [maker(error)]
                    )
                }
            }

        switch state.provisioningState {
        case .notReady:
            return .notReady
        case .loading:
            if let sections = boxedValueToSections(state.value), numberOfItems(sections) > 0 {
                // Loading and there are fallback items, return them
                return .readyToDisplay(
                    state,
                    sections
                )
            } else if state.error != nil {
                // Loading, error, and there are no fallback items > return loading item
                // if the loadImpulse permits it, or if no loadImpulse available (== .notReady)
                if state.loadImpulse?.type.showLoadingIndicator ?? true, let loading = loading {
                    return loading
                } else {
                    return empty
                }
            } else if state.value != nil, let noResults = noResults {
                // Loading and there is an empty fallback balue, return noResults item.
                // We could also just display only the loadingSection instead, but then the view
                // would e.g. jump from noResults to loading-only to noResults. While technically
                // correct, keeping noResults is less irritating.
                return noResults
            } else {
                // Loading and there are no fallback items, return loading item
                if state.loadImpulse?.type.showLoadingIndicator ?? true, let loading = loading {
                    return loading
                } else {
                    return empty
                }
            }
        case .result:
            switch errorsConfiguration {
            case .alwaysShowError:
                if let error = state.error, let showError = showError {
                    return showError(error)
                } else if let value = state.value {
                    if let sections = boxedValueToSections(value), numberOfItems(sections) > 0 {
                        // Success, return items
                        return .readyToDisplay(
                            state,
                            sections
                        )
                    } else {
                        // Success without items, return noResults
                        return noResults ?? empty
                    }
                } else {
                    // No error and no value, return noResults
                    return noResults ?? empty
                }
            case .ignoreErrorIfCachedValueAvailable:
                if let value = state.value {
                    if let sections = boxedValueToSections(value), numberOfItems(sections) > 0 {
                        // Success, return items
                        return .readyToDisplay(
                            state,
                            sections
                        )
                    } else {
                        // Success without items, return noResults
                        return noResults ?? empty
                    }
                } else if let error = state.error, let showError = showError {
                    return showError(error)
                } else {
                    // No error and no value, return noResults
                    return noResults ?? empty
                }
            }
        }
    }
}

public extension Resource.ListBinding.MakeListViewStateFromResourceValue {
    typealias EnhancedListBinding = Resource.ListBinding<
        EnhancedItemModel<ItemModelType>,
        SectionModelType,
        View,
        ContainerView
    >

    func enhance() -> EnhancedListBinding.MakeListViewStateFromResourceValue {
        .init { value, state -> EnhancedListBinding.ListViewState in
            let baseListViewState = self.makeListViewState(value, state)
            switch baseListViewState {
            case let .readyToDisplay(state, sections):
                return .readyToDisplay(
                    state,
                    sections.mapElements(transform: EnhancedItemModel.baseItem)
                )
            case .notReady:
                return .notReady
            }
        }
    }
}

private extension ArraySection {
    func mapElements<TransformedElement>(transform: (Element) -> TransformedElement)
    -> ArraySection<Model, TransformedElement> {
        .init(model: model, elements: elements.map(transform))
    }
}

private extension Array {
    func mapElements<Model, SectionElement, TransformedElement>(
        transform: (SectionElement) -> TransformedElement
    ) -> [ArraySection<Model, TransformedElement>]
    where Element == ArraySection<Model, SectionElement> {
        map { $0.mapElements(transform: transform) }
    }
}

public enum EnhancedListViewStateErrorsConfiguration {
    case alwaysShowError
    case ignoreErrorIfCachedValueAvailable
}
