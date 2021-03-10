import Foundation

/// Conformance to this type lets callers determine whether
/// `Self` is cache-compatible with another instance.
///
/// See `isCacheCompatible(to:)` for more documentation.
public protocol Cacheable: Equatable {

    /// Returns true if `other` can be used as a
    /// cache version of self, or vice versa.
    /// In most cases, returning `self == other` will be
    /// fine. But since this is important to consider for all
    /// models, no default implementation is provided.
    ///
    /// Example scenario:
    /// An app uses authentication. It has successfully loaded resources
    /// from the API with a token that is stored inside a `Cacheable`
    /// query. Now the token changes. It is expected that the resources
    /// loaded with the previous token shall not be shown anymore.
    /// In order to discard those (now invalid) resources, the app
    /// needs to have a way of determining whether a resource is still
    /// valid. That's what
    /// changed between requests - the old user's data must not be shown
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
