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
public struct EquatableBox<Value: Any>: Equatable {
    public let value: Value
    let equalityId: String
    
    public init(_ value: Value) {
        self.value = value
        self.equalityId = UUID().uuidString
    }
    
    public static func ==(lhs: EquatableBox, rhs: EquatableBox) -> Bool {
        return lhs.equalityId == rhs.equalityId
    }
}

extension EquatableBox: Codable where Value : Codable {}
