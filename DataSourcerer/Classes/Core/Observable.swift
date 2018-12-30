import Foundation

public protocol UntypedObservable {
    func removeObserver(with: Int)
}

public protocol TypedObservable: UntypedObservable {
    associatedtype ObservedValue
    typealias ValuesOverTime = (ObservedValue) -> Void

    func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable
}

/// Retains the current value and sends an initial value
/// synchronously on subscription.
public protocol StatefulObservable: TypedObservable {
    var currentValue: SynchronizedProperty<ObservedValue> { get }
}

public extension StatefulObservable {
    var any: AnyValueRetainingObservable<ObservedValue> {
        return AnyValueRetainingObservable(self)
    }
}

public struct AnyValueRetainingObservable<T_>: StatefulObservable {
    public typealias ObservedValue = T_

    public let currentValue: SynchronizedProperty<ObservedValue>
    private var _observe: (@escaping ValuesOverTime) -> Disposable
    private var _removeObserver: (Int) -> Void

    init<O: StatefulObservable>(_ observable: O) where O.ObservedValue == ObservedValue {
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
public final class UIObservable<T_>: StatefulObservable {

    public typealias ObservedValue = T_

    public typealias T = T_

    private let innerObservable: DefaultStatefulObservable<T>
    private var wrappedDisposable: Disposable?
    private let executer = SynchronizedExecuter(queue: DispatchQueue.main)

    public var currentValue: SynchronizedProperty<T_> {
        return innerObservable.currentValue
    }

    public init(_ wrappedObservable: AnyValueRetainingObservable<T>) {
        assert(Thread.isMainThread, "UIValueRetainingObservable.init must be called on main thread.")

        innerObservable = DefaultStatefulObservable(wrappedObservable.currentValue.value)
        wrappedDisposable = wrappedObservable.observe { [weak self] value in
            self?.executer.sync {
                self?.innerObservable.emit(value)
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

open class DefaultStatefulObservable<T_>: StatefulObservable {
    public typealias ObservedValue = T_
    public typealias ValuesOverTime = (ObservedValue) -> Void

    private let mutableLastValue: SynchronizedMutableProperty<ObservedValue>
    public lazy var currentValue = SynchronizedProperty<ObservedValue>(self.mutableLastValue)

    private let observers = SynchronizedMutableProperty([Int: ValuesOverTime]())

    public init(_ firstValue: ObservedValue) {
        mutableLastValue = SynchronizedMutableProperty<ObservedValue>(firstValue)
    }

    open func observe(_ observe: @escaping ValuesOverTime) -> Disposable {

        // Send current value
        observe(currentValue.value)

        let uniqueKey = Int(arc4random_uniform(10_000))
        observers.modify({ $0[uniqueKey] = observe })

        // Keeps a reference to self until disposed:
        return ActionDisposable {
            self.removeObserver(with: uniqueKey)
        }
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
