import Foundation

public extension Resource {

    /// Describes an impulse for loading a `Resource`.
    struct LoadImpulse: Equatable {
        public var query: Query
        public let type: LoadImpulseType
        internal let id: UUID

        public init(
            query: Query,
            type: LoadImpulseType,
            id: UUID = UUID()
        ) {
            self.query = query
            self.type = type
            self.id = id
        }

        public func with(query: Query) -> LoadImpulse {
            var modified = self
            modified.query = query
            return modified
        }

        func isCacheCompatible(_ candidate: LoadImpulse) -> Bool {
            candidate.query.isCacheCompatible(to: query)
        }

        public static func ==(lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }
}

public extension Resource.LoadImpulse where Query == NoQuery {
    init(type: LoadImpulseType) {
        self.init(
            query: NoQuery(),
            type: type
        )
    }

    static var initial: Self {
        Self.init(
            type: LoadImpulseType(
                context: .fullRefresh,
                actor: .system,
                showLoadingIndicator: true
            )
        )
    }
}

public struct LoadImpulseType: Codable, Equatable {

    public let context: Context
    public let actor: Actor
    public let showLoadingIndicator: Bool

    public static let initial = LoadImpulseType(
        context: .initial,
        actor: .system,
        showLoadingIndicator: true
    )

    public init(context: Context, actor: Actor, showLoadingIndicator: Bool) {
        self.context = context
        self.actor = actor
        self.showLoadingIndicator = showLoadingIndicator
    }

    public enum Context: String, Codable, Equatable {
        case initial
        case fullRefresh
        case partialLoad
        case partialReload
    }

    public enum Actor: String, Codable, Equatable {
        case user
        case system
    }
}

extension Resource.LoadImpulse: Codable where Query: Codable {}
