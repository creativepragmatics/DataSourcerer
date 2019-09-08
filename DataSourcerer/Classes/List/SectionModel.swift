import DifferenceKit
import Foundation

public protocol SectionModel: Differentiable where DifferenceIdentifier == String {

    // Required to display configuration or system messages or errors
    // (will probably contain only one descriptive cell)
    init()
}

/// To be used when a list view shall have no _visible_ sections at all.
/// This is mainly for matching generics such that a SingleSection*Controller
/// can be created cleanly.
public struct SingleSection : SectionModel {
    public let differenceIdentifier: String = "singleSection"

    public init() {}

    public func isContentEqual(to source: SingleSection) -> Bool {
        return source.differenceIdentifier == self.differenceIdentifier
    }
}

