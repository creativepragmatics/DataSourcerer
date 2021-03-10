import Foundation
import ReactiveSwift

public extension Property {
    static func constant(_ value: Value) -> Property<Value> {
        Property(value: value)
    }
}
