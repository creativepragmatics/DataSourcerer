import Foundation

public struct LoadImpulse<P: Parameters>: Equatable {

    public var parameters: P
    public let skipIfResultAvailable: Bool

    public init(parameters: P, skipIfResultAvailable: Bool = false) {
        self.parameters = parameters
        self.skipIfResultAvailable = skipIfResultAvailable
    }

    public func with(parameters: P) -> LoadImpulse<P> {
        var modified = self
        modified.parameters = parameters
        return modified
    }

    func isCacheCompatible(_ candidate: LoadImpulse<P>) -> Bool {
        return parameters.isCacheCompatible(candidate.parameters)
    }
}

extension LoadImpulse : Codable where P: Codable {}
