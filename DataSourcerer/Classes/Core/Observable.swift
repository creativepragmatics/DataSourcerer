import Foundation

public protocol UntypedObservable {
    func removeObserver(with: Int)
}

public protocol TypedObservable: UntypedObservable {
    associatedtype ObservedValue
    typealias ValuesOverTime = (ObservedValue) -> Void

    func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable
}

public protocol ValueRetainingObservable: TypedObservable {
    var currentValue: SynchronizedProperty<ObservedValue> { get }
}

public extension ValueRetainingObservable {
    var any: AnyValueRetainingObservable<ObservedValue> {
        return AnyValueRetainingObservable(self)
    }
}

public struct AnyValueRetainingObservable<T_>: ValueRetainingObservable {
    public typealias ObservedValue = T_

    public let currentValue: SynchronizedProperty<ObservedValue>
    private var _observe: (@escaping ValuesOverTime) -> Disposable
    private var _removeObserver: (Int) -> Void

    init<O: ValueRetainingObservable>(_ observable: O) where O.ObservedValue == ObservedValue {
        self.currentValue = observable.currentValue
        self._observe = observable.observe
        self._removeObserver = observable.removeObserver
    }

    public func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable {
        return _observe(valuesOverTime)
    }

    public func removeObserver(with key: Int) {
        _removeObserver(key)
    }
}

/// Operates only on main thread. Make sure to call init() on
/// the main thread.
public final class UIObservable<T_>: ValueRetainingObservable {

    public typealias ObservedValue = T_

    public typealias T = T_

    private let innerObservable: DefaultObservable<T>
    private var wrappedDisposable: Disposable?

    public var currentValue: SynchronizedProperty<T_> {
        return innerObservable.currentValue
    }

    public init(_ wrappedObservable: AnyValueRetainingObservable<T>) {
        assert(Thread.isMainThread, "UIValueRetainingObservable.init must be called on main thread.")

        innerObservable = DefaultObservable(wrappedObservable.currentValue.value)
        wrappedDisposable = wrappedObservable.observe { [weak self] value in
            if Thread.isMainThread {
                self?.innerObservable.emit(value)
            } else {
                // Async because sync would be too risky for deadlocks?
                DispatchQueue.main.async { [weak self] in
                    self?.innerObservable.emit(value)
                }
            }
        }
    }

    deinit {
        wrappedDisposable?.dispose()
    }

    public func observe(_ valuesOverTime: @escaping (T_) -> Void) -> Disposable {
        return innerObservable.observe(valuesOverTime)
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }
}

open class DefaultObservable<T_>: ValueRetainingObservable {
    public typealias ObservedValue = T_
    public typealias ValuesOverTime = (ObservedValue) -> Void

    private let mutableLastValue: SynchronizedMutableProperty<ObservedValue>
    public lazy var currentValue = SynchronizedProperty<ObservedValue>(self.mutableLastValue)

    private let observers = SynchronizedMutableProperty([Int: ValuesOverTime]())

    public init(_ firstValue: ObservedValue) {
        mutableLastValue = SynchronizedMutableProperty<ObservedValue>(firstValue)
    }

    open func observe(_ observe: @escaping ValuesOverTime) -> Disposable {

        let uniqueKey = Int(arc4random_uniform(10_000))
        observers.modify({ $0[uniqueKey] = observe })
        return ObserverDisposable(observable: self, key: uniqueKey)
    }

    open func emit(_ value: ObservedValue) {

        mutableLastValue.value = value
        observers.value.values.forEach({ valuesOverTime in
            valuesOverTime(value)
        })
    }

    open func removeObserver(with key: Int) {

        observers.modify({ $0.removeValue(forKey: key) })
    }
}
