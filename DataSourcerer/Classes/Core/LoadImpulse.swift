import Foundation

public struct LoadImpulse<P: ResourceParams>: Equatable {

    public var params: P
    public let skipIfResultAvailable: Bool

    public init(params: P, skipIfResultAvailable: Bool = false) {
        self.params = params
        self.skipIfResultAvailable = skipIfResultAvailable
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

extension LoadImpulse : Codable where P: Codable {}
