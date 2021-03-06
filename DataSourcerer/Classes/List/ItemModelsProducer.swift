import Foundation

public struct ItemModelsProducer
<Value, P: ResourceParams, E, ItemModelType: ItemModel, SectionModelType: SectionModel>
where ItemModelType.E == E {

    public typealias StateToListViewState =
        (ResourceState<Value, P, E>,
        ValueToListViewStateTransformer<Value, P, E, ItemModelType, SectionModelType>)
        -> ListViewState<Value, P, E, ItemModelType, SectionModelType>

    internal let stateToListViewState: StateToListViewState
    internal let valueToListViewStateTransformer:
    ValueToListViewStateTransformer<Value, P, E, ItemModelType, SectionModelType>

    public init(
        stateToListViewState: @escaping StateToListViewState,
        valueToListViewStateTransformer:
            ValueToListViewStateTransformer<Value, P, E, ItemModelType, SectionModelType>
    ) {

        self.stateToListViewState = stateToListViewState
        self.valueToListViewStateTransformer = valueToListViewStateTransformer
    }

    public init(
        baseValueToListViewStateTransformer:
            ValueToListViewStateTransformer<Value, P, E, ItemModelType, SectionModelType>
    ) {

        self.stateToListViewState = { state, valueToListViewStateTransformer in
            if let value = state.value?.value {
                return valueToListViewStateTransformer.valueToListViewState(value, state)
            } else {
                return .notReady
            }
        }
        self.valueToListViewStateTransformer = baseValueToListViewStateTransformer
    }

    public static func withSingleSectionItems<P: ResourceParams>(
        _ singleSectionItems: @escaping (Value, ResourceState<Value, P, E>) -> [ItemModelType]
        ) -> ItemModelsProducer<Value, P, E, ItemModelType, NoSection> where ItemModelType.E == E {

        let valueToListViewStateTransformer =
            ValueToListViewStateTransformer<Value, P, E, ItemModelType, NoSection>(
                valueToSingleSectionItems: { value, state in
                    return singleSectionItems(value, state)
                }
            )

        return ItemModelsProducer<Value, P, E, ItemModelType, NoSection>(
            baseValueToListViewStateTransformer: valueToListViewStateTransformer
        )
    }

    public func listViewState(with state: ResourceState<Value, P, E>)
        -> ListViewState<Value, P, E, ItemModelType, SectionModelType> {

            return stateToListViewState(state, valueToListViewStateTransformer)
    }

}

public struct ValueToListViewStateTransformer
<Value, P: ResourceParams, E: ResourceError, ItemModelType: ItemModel, SectionModelType: SectionModel> {

    // We require Value to be passed besides the ResourceState, even though the
    // ResourceState will contain that same Value. We do this to make sure that
    // a Value is indeed available (compiletime safety). If ResourceState is
    // refactored to an enum (again) later, we can get rid of this.
    public typealias ValueToListViewState = (Value, ResourceState<Value, P, E>)
        -> ListViewState<Value, P, E, ItemModelType, SectionModelType>

    public let valueToListViewState: ValueToListViewState

    public init(_ valueToListViewState: @escaping ValueToListViewState) {
        self.valueToListViewState = valueToListViewState
    }

    public init(
        valueToSections: @escaping (Value, ResourceState<Value, P, E>)
        -> [SectionAndItems<ItemModelType, SectionModelType>]
    ) {
        self.valueToListViewState = { value, resourceState in
            return ListViewState.readyToDisplay(
                resourceState,
                valueToSections(value, resourceState)
            )
        }
    }

}

public extension ValueToListViewStateTransformer where SectionModelType == NoSection {

    init(
        valueToSingleSectionItems: @escaping (Value, ResourceState<Value, P, E>) -> [ItemModelType]
    ) {
        self.valueToListViewState = { value, state in
            let sectionAndItems = SectionAndItems(
                NoSection(),
                valueToSingleSectionItems(value, state)
            )
            return ListViewState.readyToDisplay(state, [sectionAndItems])
        }
    }
}
