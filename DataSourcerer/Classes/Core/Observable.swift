import Foundation

/// Base observable type.
public protocol ObservableProtocol {
    func removeObserver(with: Int)
}

/// Typed observable which sends values to each
/// observer (subscribed via `observe(_)`).
public protocol TypedObservableProtocol: ObservableProtocol {
    associatedtype ObservedValue
    typealias ValuesOverTime = (ObservedValue) -> Void

    func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable
}
