import Dwifft
import Foundation

public extension ListViewState {

    var sectionedValues: SectionedValues<SectionModelType, ItemModelType> {
        return SectionedValues((sectionsWithItems ?? []).map({ ($0.section, $0.items) }))
    }
}
