import Foundation

public protocol Parameters : Equatable {

    /// Returns true if candidate can be used as a
    /// cache version of self, or vice versa.
    /// In most cases, returning `self == candidate` will be
    /// fine.
    ///
    /// Consider the case that the authenticated user has changed
    /// between requests - the old user's data must not be shown
    /// anymore. The cache must discard the old stored response.
    /// In order to do so, the cache will use this function to
    /// compare the cached response's parameters with the new
    /// parameters. So, in that case, false must be returned if
    /// the new parameters show that the authenticated user's email
    /// address or auth token has changed.
    ///
    /// Another scenario would just be changed request parameters,
    /// like the page offset of a paginated datasource. The cache must
    /// not continue using an old request's response then.
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
