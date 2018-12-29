import Foundation

public protocol UntypedObservable {
    func removeObserver(with: Int)
}

public protocol TypedObservable: UntypedObservable {
    associatedtype ObservedValue
    typealias ValuesOverTime = (ObservedValue) -> Void

    func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable
}

public protocol LastValueRetainingObservable: TypedObservable {
    var lastValue: SynchronizedProperty<ObservedValue?> { get }
}

public extension LastValueRetainingObservable {
    var any: AnyLastValueRetainingObservable<ObservedValue> {
        return AnyLastValueRetainingObservable(self)
    }
}

public struct AnyLastValueRetainingObservable<T_>: LastValueRetainingObservable {
    public typealias ObservedValue = T_

    public let lastValue: SynchronizedProperty<ObservedValue?>
    private var _observe: (@escaping ValuesOverTime) -> Disposable
    private var _removeObserver: (Int) -> Void

    init<O: LastValueRetainingObservable>(_ observable: O) where O.ObservedValue == ObservedValue {
        self.lastValue = observable.lastValue
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

open class DefaultObservable<T_>: LastValueRetainingObservable {
    public typealias ObservedValue = T_
    public typealias ValuesOverTime = (ObservedValue) -> Void

    private let mutableLastValue = SynchronizedMutableProperty<ObservedValue?>(nil)
    public lazy var lastValue = SynchronizedProperty<ObservedValue?>(self.mutableLastValue)

    private let observers = SynchronizedMutableProperty([Int: ValuesOverTime]())

    public init() {}

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
