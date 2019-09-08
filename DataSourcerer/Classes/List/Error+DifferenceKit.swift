import DifferenceKit
import Foundation

extension NoResourceError: Differentiable {

    public var differenceIdentifier: String {
        return "NoResourceError"
    }

    public func isContentEqual(to source: NoResourceError) -> Bool {
        return source.differenceIdentifier == differenceIdentifier
    }

}
