import Foundation

/// Describes where a `Resource` is at within its lifetime, before or
/// following a load impulse.
public enum ProvisioningState: Int, Equatable, Codable {
    case notReady
    case loading
    case result
}

