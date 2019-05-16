import Foundation

public enum ListViewState
    <Value, P: ResourceParams, E: ResourceError, ItemModelType: ItemModel,
    SectionModelType: SectionModel>: Equatable {

    case notReady
    case readyToDisplay(
        ResourceState<Value, P, E>,
        [SectionAndItems<ItemModelType, SectionModelType>]
    )

}

public extension ListViewState {

    var sectionsAndItems: [SectionAndItems<ItemModelType, SectionModelType>]? {
        switch self {
        case .notReady: return nil
        case let .readyToDisplay(_, sectionsAndItems): return sectionsAndItems
        }
    }

    func doCellsDiffer(other: ListViewState) -> Bool {
        switch (self, other) {
        case (.notReady, .notReady):
            return false
        case (.notReady, .readyToDisplay), (.readyToDisplay, .notReady):
            return true
        case let (.readyToDisplay(_, lhsContent),
                  .readyToDisplay(_, rhsContent)):
            return lhsContent == rhsContent
        }
    }
}
