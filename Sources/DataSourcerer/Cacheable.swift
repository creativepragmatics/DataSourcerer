import Foundation

public protocol Cacheable: Equatable {

    /// Returns true if `other` can be used as a
    /// cache version of self, or vice versa.
    /// In most cases, returning `self == other` will be
    /// fine. But since this is important to consider for all
    /// models, no default implementation is provided.
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
    func isCacheCompatible(to other: Self) -> Bool
}
