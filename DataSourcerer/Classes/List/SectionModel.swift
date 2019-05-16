import Foundation

public protocol SectionModel: Equatable {

    // Required to display configuration or system messages or errors
    // (will probably contain only one descriptive cell)
    init()
}

/// Section implementation that has no data attached. Ideal
/// for lists where all data resides in the cells.
public struct PlainSectionModel : SectionModel {
    public init() {}
}

/// To be used when a list view shall have no _visible_ sections at all.
/// This is mainly for matching generics such that a SingleSection*Controller
/// can be created cleanly.
public struct SingleSection: SectionModel {
    public init() {}
}
