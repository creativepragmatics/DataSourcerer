import Foundation

public protocol Parameters : Equatable {

    /// Returns true if candidate can be used as a
    /// cache version of self, or vice versa.
    /// Consider the case that the authenticated user has changed,
    /// then the old user's data must not be shown anymore. In
    /// that case, false must be returned if e.g. the parameters'
    /// email address or auth token has changed.
    func isCacheCompatible(_ candidate: Self) -> Bool
}

public struct VoidParameters : Parameters {
    public func isCacheCompatible(_ candidate: VoidParameters) -> Bool { return true }

    static let initial = VoidParameters()
}

extension Sequence where Element : Parameters {

    var areParametersCacheCompatible: Bool {
        var first: Element?
        for candidate in self {
            if let foundFirst = first {
                if foundFirst.isCacheCompatible(candidate) {
                    continue
                } else {
                    return false
                }
            } else {
                first = candidate
            }
        }

        return true
    }
}
