import Foundation

public protocol SourcererExtensionsProvider {}

public extension SourcererExtensionsProvider {
    var sourcerer: SourcererExtension<Self> {
        return SourcererExtension(self)
    }

    static var sourcerer: SourcererExtension<Self>.Type {
        return SourcererExtension<Self>.self
    }
}

/// A proxy which hosts reactive extensions of `Base`.
public struct SourcererExtension<Base> {
    /// The `Base` instance the extensions would be invoked with.
    public let base: Base

    /// Construct a proxy
    ///
    /// - parameters:
    ///   - base: The object to be proxied.
    fileprivate init(_ base: Base) {
        self.base = base
    }
}
