import DifferenceKit
import Foundation

public enum ListViewState
    <Value, P: ResourceParams, E: ResourceError, ItemModelType: ItemModel,
    SectionModelType: SectionModel> {

    case notReady
    case readyToDisplay(
        ResourceState<Value, P, E>,
        [ArraySection<SectionModelType, ItemModelType>]
    )

}

public extension ListViewState {

    var sections: [ArraySection<SectionModelType, ItemModelType>]? {
        switch self {
        case .notReady: return nil
        case let .readyToDisplay(_, sectionsAndItems): return sectionsAndItems
        }
    }
}
