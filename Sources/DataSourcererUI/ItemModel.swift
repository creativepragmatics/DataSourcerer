import Foundation
import DifferenceKit

public protocol ItemModel: Differentiable
where DifferenceIdentifier == String, Failure.DifferenceIdentifier == String {
    associatedtype Failure: Error & Differentiable

    // Required to display configuration or system errors
    // for easier debugging.
    init(error: Failure)
}
