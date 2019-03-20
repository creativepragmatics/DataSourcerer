import Foundation

/// Resource parameters, used in `LoadImpulse`. The most
/// likely use case is to provide data for an API or cache
/// request. It should contain ALL data required for such a
/// request (including authorization tokens, headers,
/// pagination page number, etc).
/// However, Public APIs or locally loaded data might not
/// require any parameters at all - in that case, `NoResourceParams`
/// might come in handy.
public protocol ResourceParams : Equatable {

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

/// Empty parameters for use cases without any parametrization
/// needs.
public struct NoResourceParams : ResourceParams, Codable {
    public func isCacheCompatible(_ candidate: NoResourceParams) -> Bool { return true }

    public init() {}
    public static let initial = NoResourceParams()
}
