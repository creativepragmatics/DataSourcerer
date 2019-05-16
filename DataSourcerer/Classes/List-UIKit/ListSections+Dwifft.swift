import Dwifft
import Foundation

public extension ListViewState {

    var dwifftSectionedValues: SectionedValues<SectionModelType, ItemModelType> {
        return SectionedValues((sectionsAndItems ?? []).map({ ($0.section, $0.items) }))
    }
}
