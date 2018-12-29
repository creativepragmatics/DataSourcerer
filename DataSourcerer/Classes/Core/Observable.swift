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

public protocol Disposable: AnyObject {
    func dispose()

    var isDisposed: Bool { get }
}

public extension Disposable {
    func disposed(by bag: DisposeBag) {
        bag.add(self)
    }
}

public final class InstanceRetainingDisposable: Disposable {

    private var instance: AnyObject?
    private var _isDisposed: Bool = false
    public var isDisposed: Bool {
        return _isDisposed
    }

    init(_ instance: AnyObject) {
        self.instance = instance
    }

    public func dispose() {
        instance = nil // remove retain on instance
        _isDisposed = true
    }

}

public class CompositeDisposable: Disposable {

    private let disposables = SynchronizedMutableProperty<[Disposable]>([])

    public var isDisposed: Bool {
        if disposables.value.contains(where: { $0.isDisposed == false }) {
            return false
        } else {
            return true
        }
    }

    init() {}

    init(_ disposables: [Disposable]) {
        self.disposables.value = disposables
    }

    public func add(_ disposable: Disposable) {
        disposables.modify({ $0 += [disposable] })
    }

    public func dispose() {
        disposables.value
            .filter({ $0.isDisposed == false })
            .forEach({ $0.dispose() })
        disposables.value = []
    }

}

public final class VoidDisposable: Disposable {

    private var _isDisposed: Bool = false
    public var isDisposed: Bool {
        return _isDisposed
    }

    public init() {}
    public func dispose() {
        _isDisposed = true
    }

}

public extension CompositeDisposable {

    convenience init(_ disposableA: Disposable, objectToRetain: AnyObject) {
        self.init([disposableA, InstanceRetainingDisposable(objectToRetain)])
    }
}

public final class ObserverDisposable: Disposable {

    var key: Int
    var observable: UntypedObservable?
    private var _isDisposed: Bool = false
    public var isDisposed: Bool {
        return _isDisposed
    }

    public init(observable: UntypedObservable, key: Int) {
        self.observable = observable
        self.key = key
    }

    public func dispose() {
        self.observable?.removeObserver(with: key)
        self.observable = nil // remove retain on instance
        _isDisposed = true
    }
}

public class DisposeBag: CompositeDisposable {

    public override init() {
        super.init()
    }

    deinit {
        dispose()
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
