import Foundation

/// Base observable type.
/// Each new subscription *might* prompt new work to be done.
/// E.g. an observable that performs a network request might
/// perform the request twice if it's observed twice.
/// If you absolutely need shared state (e.g. each observation gets
/// just the latest network request's result), consider using
/// `ObservableProperty`.
public protocol ObservableProtocol {
    associatedtype ObservedValue
    typealias ValuesOverTime = (ObservedValue) -> Void

    func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable
}

public extension ObservableProtocol {
    var any: AnyObservable<ObservedValue> {
        return AnyObservable(self)
    }
}

public struct AnyObservable<ObservedValue_>: ObservableProtocol {
    public typealias ObservedValue = ObservedValue_

    private let _observe: (@escaping ValuesOverTime) -> Disposable

    public init<O: ObservableProtocol>(_ observable: O) where O.ObservedValue == ObservedValue {
        self._observe = observable.observe
    }

    public func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable {
        return _observe(valuesOverTime)
    }
}
