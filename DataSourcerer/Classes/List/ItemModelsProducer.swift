import Foundation

public struct ItemModelsProducer
<Value, P: ResourceParams, E, ItemModelType: ItemModel, SectionModelType: SectionModel>
where ItemModelType.E == E {

    public typealias StateToListViewState =
        (ResourceState<Value, P, E>, ValueToListViewStateTransformer<Value, P, ItemModelType, SectionModelType>)
        -> ListViewState<P, ItemModelType, SectionModelType>

    private let stateToListViewState: StateToListViewState
    private let valueToListViewStateTransformer:
    ValueToListViewStateTransformer<Value, P, ItemModelType, SectionModelType>

    public init(
        stateToListViewState: @escaping StateToListViewState,
        valueToListViewStateTransformer:
            ValueToListViewStateTransformer<Value, P, ItemModelType, SectionModelType>
    ) {

        self.stateToListViewState = stateToListViewState
        self.valueToListViewStateTransformer = valueToListViewStateTransformer
    }

    public init(
        baseValueToListViewStateTransformer:
            ValueToListViewStateTransformer<Value, P, ItemModelType, SectionModelType>
    ) {

        self.stateToListViewState = { state, valueToListViewStateTransformer in
            if let value = state.value?.value, let loadImpulse = state.loadImpulse {
                return valueToListViewStateTransformer.valueToListViewState(
                    value,
                    loadImpulse,
                    state.provisioningState
                )
            } else {
                return .notReady
            }
        }
        self.valueToListViewStateTransformer = baseValueToListViewStateTransformer
    }

    public static func withSingleSectionItems<P: ResourceParams>(
        _ singleSectionItems: @escaping (Value, LoadImpulse<P>, ProvisioningState) -> [ItemModelType]
        ) -> ItemModelsProducer<Value, P, E, ItemModelType, NoSection> where ItemModelType.E == E {

        let valueToListViewStateTransformer =
            ValueToListViewStateTransformer<Value, P, ItemModelType, NoSection>(
                valueToSingleSectionItems: { value, loadImpulse, provisioningState in
                    return singleSectionItems(value, loadImpulse, provisioningState)
                }
            )

        return ItemModelsProducer<Value, P, E, ItemModelType, NoSection>(
            baseValueToListViewStateTransformer: valueToListViewStateTransformer
        )
    }

    public func listViewState(with state: ResourceState<Value, P, E>)
        -> ListViewState<P, ItemModelType, SectionModelType> {

            return stateToListViewState(state, valueToListViewStateTransformer)
    }

    public func showLoadingAndErrorStates(noResultsText: String)
        -> ItemModelsProducer<Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType> {

            return ItemModelsProducer<Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType>(
                stateToListViewState: { state, valueToIdiomaticListViewStateTransformer
                    -> ListViewState<P, IdiomaticItemModel<ItemModelType>, SectionModelType> in

                    return state.addLoadingAndErrorStates(
                        valueToIdiomaticListViewStateTransformer: valueToIdiomaticListViewStateTransformer,
                        noResultsText: noResultsText
                    )
                },
                valueToListViewStateTransformer: valueToListViewStateTransformer.showLoadingAndErrorStates()
            )
    }

}

public struct ValueToListViewStateTransformer
<Value, P: ResourceParams, ItemModelType: ItemModel, SectionModelType: SectionModel> {

    public typealias ValueToListViewState = (Value, LoadImpulse<P>, ProvisioningState)
        -> ListViewState<P, ItemModelType, SectionModelType>

    public let valueToListViewState: ValueToListViewState

    public init(_ valueToListViewState: @escaping ValueToListViewState) {
        self.valueToListViewState = valueToListViewState
    }

    public init(
        valueToSections: @escaping (Value, LoadImpulse<P>, ProvisioningState)
        -> [SectionAndItems<ItemModelType, SectionModelType>]
    ) {
        self.valueToListViewState = { value, loadImpulse, provisioningState in
            return ListViewState.readyToDisplay(
                loadImpulse,
                provisioningState,
                valueToSections(value, loadImpulse, provisioningState)
            )
        }
    }

    public func showLoadingAndErrorStates()
        -> ValueToListViewStateTransformer<Value, P, IdiomaticItemModel<ItemModelType>, SectionModelType> {

            return ValueToListViewStateTransformer
                <Value, P, IdiomaticItemModel<ItemModelType>, SectionModelType> { value,
                    loadImpulse, provisioningState
                    -> ListViewState<P, IdiomaticItemModel<ItemModelType>, SectionModelType> in

                    let innerListViewState = self.valueToListViewState(value, loadImpulse, provisioningState)
                    switch innerListViewState {
                    case let .readyToDisplay(loadImpulse, provisioningState, sectionsWithItems):
                        return ListViewState.readyToDisplay(
                            loadImpulse,
                            provisioningState,
                            sectionsWithItems.map { sectionAndItems in
                                return SectionAndItems(
                                    sectionAndItems.section,
                                    sectionAndItems.items.map { IdiomaticItemModel.baseItem($0) }
                                )
                            }
                        )
                    case .notReady:
                        return .notReady
                    }
            }
    }
}

public extension ValueToListViewStateTransformer where SectionModelType == NoSection {

    init(
        valueToSingleSectionItems: @escaping (Value, LoadImpulse<P>, ProvisioningState) -> [ItemModelType]
    ) {
        self.valueToListViewState = { value, loadImpulse, provisioningState in
            let sectionAndItems = SectionAndItems(
                NoSection(),
                valueToSingleSectionItems(value, loadImpulse, provisioningState)
            )
            return ListViewState.readyToDisplay(loadImpulse, provisioningState, [sectionAndItems])
        }
    }
}
