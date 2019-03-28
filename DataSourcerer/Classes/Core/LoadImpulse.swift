import Foundation

public struct LoadImpulse<P: ResourceParams>: Equatable {

    public var params: P
    public let type: LoadImpulseType

    public init(
        params: P,
        type: LoadImpulseType
    ) {
        self.params = params
        self.type = type
    }

    public func with(params: P) -> LoadImpulse<P> {
        var modified = self
        modified.params = params
        return modified
    }

    func isCacheCompatible(_ candidate: LoadImpulse<P>) -> Bool {
        return params.isCacheCompatible(candidate.params)
    }
}

public struct LoadImpulseType: Codable, Equatable {

    public let mode: Mode
    public let issuer: Issuer
    public let showLoadingIndicator: Bool

    public init(mode: Mode, issuer: Issuer) {
        switch issuer {
        case .system:
            self.init(mode: mode, issuer: issuer, showLoadingIndicator: true)
        case .user:
            // For pull-to-refresh, we don't want a
            // second loading indicator beneath the
            // refresh control.
            self.init(mode: mode, issuer: issuer, showLoadingIndicator: false)
        }
    }

    public init(mode: Mode, issuer: Issuer, showLoadingIndicator: Bool) {
        self.mode = mode
        self.issuer = issuer
        self.showLoadingIndicator = showLoadingIndicator
    }

    public enum Mode: String, Codable, Equatable {
        case initial
        case fullRefresh
        case partialLoad
        case partialReload
    }

    public enum Issuer: String, Codable, Equatable {
        case user
        case system
    }

    public static let initial = LoadImpulseType(mode: .initial, issuer: .system)
}

extension LoadImpulse : Codable where P: Codable {}
