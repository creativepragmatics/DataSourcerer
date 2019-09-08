import Foundation
import DifferenceKit

public protocol ItemModel: Differentiable where DifferenceIdentifier == String,
E.DifferenceIdentifier == String {
    associatedtype E: ResourceError & Differentiable

    // Required to display configuration or system errors
    // for easier debugging.
    init(error: E)
}
