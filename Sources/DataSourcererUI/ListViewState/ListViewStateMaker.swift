import DataSourcerer
import DifferenceKit
import Foundation
import ReactiveSwift
import UIKit

public extension Resource.ListBinding {
    struct ListViewStateMaker {
        public typealias MakeListViewState =
            (Resource.State, MakeListViewStateFromResourceValue) -> ListViewState
        let makeListViewState: MakeListViewState
        let makeListViewStateFromResourceValue: MakeListViewStateFromResourceValue

        public init(
            makeListViewState: @escaping MakeListViewState,
            makeListViewStateFromResourceValue: MakeListViewStateFromResourceValue
        ) {
            self.makeListViewState = makeListViewState
            self.makeListViewStateFromResourceValue = makeListViewStateFromResourceValue
        }

        public init(
            makeListViewStateFromResourceValue: MakeListViewStateFromResourceValue
        ) {
            self.makeListViewState = { state, makeListViewStateFromResourceValue in
                if let value = state.value?.value {
                    return makeListViewStateFromResourceValue.makeListViewState(value, state)
                } else {
                    return .notReady
                }
            }
            self.makeListViewStateFromResourceValue = makeListViewStateFromResourceValue
        }

        public func callAsFunction(state: Resource.State) -> ListViewState {
            makeListViewState(state, makeListViewStateFromResourceValue)
        }
    }
}

public extension Resource.ListBinding {
    struct MakeListViewStateFromResourceValue {

        // We require Value to be passed besides the ResourceState, even though the
        // ResourceState will contain that same Value. We do this to make sure that
        // a Value is indeed available (compiletime safety).
        public typealias MakeListViewState = (Value, Resource.State) -> ListViewState

        public let makeListViewState: MakeListViewState

        public init(_ makeListViewState: @escaping MakeListViewState) {
            self.makeListViewState = makeListViewState
        }

        public init(
            makeSections: @escaping (Value, Resource.State) -> [DiffableSection]
        ) {
            self.makeListViewState = { value, resourceState in
                ListViewState.readyToDisplay(
                    resourceState,
                    makeSections(value, resourceState)
                )
            }
        }
    }
}

public extension Resource.ListBinding.ListViewStateMaker {
    static func multiSectionItems(
        _ makeMultiSectionItems: Property<
            (Value, Resource.State) -> [ArraySection<SectionModelType, ItemModelType>]
        >
    ) -> Property<Self> {
        makeMultiSectionItems.map {
            Self.init(
                makeListViewStateFromResourceValue: .init(
                    makeSections: $0
                )
            )
        }
    }
}

public extension Resource.ListBinding.ListViewStateMaker
where SectionModelType == SingleSection {
    static func singleSectionItems(
        _ makeSingleSectionItems: Property<(Value, Resource.State) -> [ItemModelType]>
    ) -> Property<Self> {
        makeSingleSectionItems.map {
            Self.init(
                makeListViewStateFromResourceValue: .init(
                    makeSingleSectionItems: $0
                )
            )
        }
    }
}

public extension Resource.ListBinding.MakeListViewStateFromResourceValue
where SectionModelType == SingleSection {
    init(
        makeSingleSectionItems: @escaping (Value, Resource.State) -> [ItemModelType]
    ) {
        self.makeListViewState = { value, state in
            let section = ArraySection(
                model: SingleSection(),
                elements: makeSingleSectionItems(value, state)
            )
            return .readyToDisplay(state, [section])
        }
    }
}
