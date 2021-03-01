import Foundation

/// Value is wrapped in a box such that equality checks can be
/// done with less overhead. The premise is that no two boxes
/// are the same due to the usage of UUIDs. Thus if two boxes
/// are the same, it can be deduced that their values must also be equal.
///
/// The ideal scenario is that a box is only instantiated when an
/// API or Cache response is generated, or if a value is read from
/// disk cache. After that, the box is just passed around (and equated a lot)
/// until the value is finally used.
public struct EquatableBox<Value>: Equatable, Hashable {
    public let value: Value
    private let equalityId: UUID

    public init(_ value: Value) {
        self.value = value
        self.equalityId = UUID()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.equalityId == rhs.equalityId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(equalityId)
    }
}

public extension EquatableBox {
    func map<Transformed>(_ transformer: (Value) -> Transformed)
    -> EquatableBox<Transformed> {
        .init(transformer(value))
    }
}

extension EquatableBox: Codable where Value : Codable {}
