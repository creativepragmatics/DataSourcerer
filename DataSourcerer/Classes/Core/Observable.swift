import Foundation

/// Base observable type.
public protocol ObservableProtocol {
    associatedtype ObservedValue
    typealias ValuesOverTime = (ObservedValue) -> Void

    func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable
}
