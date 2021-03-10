import DataSourcerer
import DifferenceKit
import Foundation

public extension Resource.ListBinding {
    enum ListViewState {
        case notReady
        case readyToDisplay(Resource.State, [DiffableSection])
    }
}

public extension Resource.ListBinding.ListViewState {
    typealias DiffableSection = ArraySection<SectionModelType, ItemModelType>
    
    var sections: [DiffableSection]? {
        switch self {
        case .notReady: return nil
        case let .readyToDisplay(_, sectionsAndItems): return sectionsAndItems
        }
    }
}
