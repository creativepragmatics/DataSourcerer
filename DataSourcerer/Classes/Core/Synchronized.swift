import Foundation

/// Thread-safe value wrapper with asynchronous setter and
/// synchronous getter.
///
/// Some discussion: https://twitter.com/manuelmaly/status/1077885584939630593?s=20
public final class SynchronizedProperty<T> {
    public typealias DidSet = Bool

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
    public func set(_ newValue: T, if condition: (T) -> Bool) -> DidSet {
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

public extension SynchronizedProperty where T: Equatable {

    /// Only sets value if `candidate` equals the current value.
    /// Returns true if value is set. Pure convenience.
    func set(_ newValue: T, ifCurrentValueIs candidate: T) -> DidSet {
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
