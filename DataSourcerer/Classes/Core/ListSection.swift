import Foundation

public protocol ListSection: Equatable {
    
    // Required to display configuration or system messages or errors
    // (will probably contain only one descriptive cell)
    init()
}

/// Section implementation that has no data attached. Ideal
/// for lists where all data resides in the cells.
public struct DefaultListSection : ListSection {
    public init() {}
}
