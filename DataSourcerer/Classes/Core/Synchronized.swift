import Foundation

/// This protocol should only be used for conformance.
internal protocol Property {
    associatedtype T

    var value: T { get }
}

public typealias PropertyDidSet = Bool

/// This protocol should only be used for conformance.
internal protocol MutableProperty: Property {
    associatedtype T

    var value: T { get set }

    func modify(_ mutate: @escaping (inout T) -> Void)
    func set(_ newValue: T, if condition: (T) -> Bool) -> PropertyDidSet
}

/// Thread-safe value wrapper with asynchronous setter and
/// synchronous getter.
///
/// Some discussion: https://twitter.com/manuelmaly/status/1077885584939630593?s=20
public final class SynchronizedMutableProperty<T_>: MutableProperty {
    public typealias T = T_

    public let executer: SynchronizedExecuter
    private var _value: T
    public var value: T {
        get {
            var currentValue: T?
            executer.sync {
                currentValue = _value
            }
            return currentValue!
        }
        set {
            executer.async {
                self._value = newValue
            }
        }
    }

    public init(_ value: T, queue: DispatchQueue? = nil) {
        self._value = value
        if let queue = queue {
            self.executer = SynchronizedExecuter(queue: queue)
        } else {
            self.executer = SynchronizedExecuter()
        }
    }

    public init(_ value: T, executer: SynchronizedExecuter) {
        self._value = value
        self.executer = executer
    }

    /// Mutate value asynchronously.
    public func modify(_ mutate: @escaping (inout T) -> Void) {
        executer.async {
            mutate(&self._value)
        }
    }

    /// Only sets value if `condition` returns true. Returns true if value
    /// is set. Pure convenience.
    public func set(_ newValue: T, if condition: (T) -> Bool) -> PropertyDidSet {
        var shouldSet = false
        executer.sync {
            shouldSet = condition(_value)
            if shouldSet {
                _value = newValue
            }
        }
        return shouldSet
    }

}

public extension SynchronizedMutableProperty {

    var readonly: SynchronizedProperty<T> {
        return SynchronizedProperty(self)
    }
}

public final class SynchronizedProperty<T_>: Property {
    public typealias T = T_

    private let mutableProperty: SynchronizedMutableProperty<T>

    public var value: T {
        return mutableProperty.value
    }

    public init(_ mutableProperty: SynchronizedMutableProperty<T>) {
        self.mutableProperty = mutableProperty
    }

}

/// Retains the last emitted value of the included `Observable`.
/// Calling `observe(_)` returns the current or initial value
/// synchronously on the queue on which `observe(_)` is called.
/// After that, `sourceObservable`'s stream of values is forwarded.
///
/// Similar to ReactiveSwift.Property.
public final class ObservableProperty<T_>: ObservableProtocol, Property {
    public typealias T = T_
    public typealias ObservedValue = T
    public typealias ValuesOverTime = (ObservedValue) -> Void

    public var value: ObservedValue {
        return mutableLastValue.value
    }
    private let mutableLastValue: SynchronizedMutableProperty<ObservedValue>
    private let broadcastObservable = BroadcastObservable<ObservedValue>()
    private let disposeBag = DisposeBag()

    public init(initialValue: ObservedValue, sourceObservable: AnyObservable<ObservedValue>) {
        mutableLastValue = SynchronizedMutableProperty<ObservedValue>(initialValue)

        sourceObservable.observe { [weak self] value in
            self?.mutableLastValue.value = value
            self?.broadcastObservable.emit(value)
        }.disposed(by: disposeBag)
    }

    public func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable {

        // Send current value
        valuesOverTime(value)

        return observeWithoutCurrentValue(valuesOverTime)
    }

    /// In some cases, the first value is not desired.
    /// We want "send first value upon observation synchronously"
    /// to be the standard behavior in observe(_), so this
    /// separate method is needed.
    public func observeWithoutCurrentValue(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable {

        // Retain self until returned disposable is disposed of. Or else,
        // this ObservableProperty might get deallocated even though there
        // are still observers.
        return CompositeDisposable(broadcastObservable.observe(valuesOverTime),
                                   objectToRetain: self)
    }
}

public extension ObservableProtocol {

    func property(initialValue: ObservedValue) -> ObservableProperty<ObservedValue> {
        return ObservableProperty(initialValue: initialValue, sourceObservable: self.any)
    }
}

internal extension MutableProperty where T: Equatable {

    /// Only sets value if `candidate` equals the current value.
    /// Returns true if value is set. Pure convenience.
    func set(_ newValue: T, ifCurrentValueIs candidate: T) -> PropertyDidSet {
        return set(newValue, if: { $0 == candidate })
    }
}

/// Thread-safe executions by employing dispatch queues.
///
/// - Read more here: http://www.fieryrobot.com/blog/2010/09/01/synchronization-using-grand-central-dispatch/
public struct SynchronizedExecuter {

    public let queue: DispatchQueue
    public let dispatchSpecificKey = DispatchSpecificKey<UInt8>()
    public let dispatchSpecificValue = UInt8.max

    public init(queue: DispatchQueue? = nil, label: String = "DataSourcerer-SynchronizedExecuter") {
        if let queue = queue {
            self.queue = queue
        } else {
            self.queue = DispatchQueue(label: label)
        }
        self.queue.setSpecific(key: dispatchSpecificKey, value: dispatchSpecificValue)
    }

    public func async(_ execute: @escaping () -> Void) {
        queue.async(execute: execute)
    }

    public func sync(_ execute: () -> Void) {
        if DispatchQueue.getSpecific(key: dispatchSpecificKey) == dispatchSpecificValue {
            execute()
        } else {
            queue.sync(execute: execute)
        }
    }

}
