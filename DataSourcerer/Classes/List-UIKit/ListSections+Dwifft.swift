import Dwifft
import Foundation

public extension ListViewState {

    var sectionedValues: SectionedValues<Section, Item> {
        return SectionedValues((sectionsWithItems ?? []).map({ ($0.section, $0.items) }))
    }
}
