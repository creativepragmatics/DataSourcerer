import Foundation

public extension StatefulObservable {

    func map<TransformedValue>(_ transform: @escaping (ObservedValue) -> (TransformedValue))
        -> StatefulObservableMapped<ObservedValue, TransformedValue> {

        return StatefulObservableMapped(self.any, transform: transform)
    }

    func observe(on queue: DispatchQueue) -> DispatchQueueObservable<Self> {
        return DispatchQueueObservable(self, queue: queue)
    }

    func observeOnUIThread() -> UIObservable<Self> {
        return UIObservable(self)
    }

    func skipRepeats(_ isEqual:@escaping (_ lhs: ObservedValue, _ rhs: ObservedValue) -> Bool)
        -> SkipRepeatsObservable<ObservedValue> {
            return SkipRepeatsObservable(self.any, isEqual: isEqual)
    }

}

public extension StatefulObservable where ObservedValue: Equatable {

    func skipRepeats() -> SkipRepeatsObservable<ObservedValue> {
            return SkipRepeatsObservable(self.any)
    }

}

public final class StatefulObservableMapped<SourceValue, TransformedValue>: StatefulObservable {
    public typealias ObservedValue = TransformedValue

    public var currentValue: SynchronizedProperty<TransformedValue> {
        return innerObservable.currentValue
    }

    private let transform: (SourceValue) -> (TransformedValue)
    private let innerObservable: DefaultStatefulObservable<TransformedValue>
    private let sourceObservable: AnyStatefulObservable<SourceValue>
    private let isObserved = SynchronizedMutableProperty<Bool>(false)

    init(_ sourceObservable: AnyStatefulObservable<SourceValue>,
         transform: @escaping (SourceValue) -> (TransformedValue)) {
        self.sourceObservable = sourceObservable
        self.transform = transform
        let initialValue = transform(sourceObservable.currentValue.value)
        self.innerObservable = DefaultStatefulObservable(initialValue)
    }

    public func observe(_ valuesOverTime: @escaping (TransformedValue) -> Void) -> Disposable {

        let innerDisposable = innerObservable.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable.add(startObserving())
        }

        return compositeDisposable
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

    private func startObserving() -> Disposable {

        return sourceObservable.observe { [weak self] sourceValue in
            guard let self = self else { return }
            self.innerObservable.emit(self.transform(sourceValue))
        }
    }

}

/// Sends values only on the defined thread.
public final class DispatchQueueObservable<SourceObservable: StatefulObservable>: StatefulObservable {

    public typealias ObservedValue = SourceObservable.ObservedValue

    private let wrappedObservable: SourceObservable
    private let innerObservable: DefaultStatefulObservable<ObservedValue>
    private let executer: SynchronizedExecuter
    private let isObserved = SynchronizedMutableProperty(false)

    public var currentValue: SynchronizedProperty<ObservedValue> {
        return innerObservable.currentValue
    }

    public init(_ wrappedObservable: SourceObservable, queue: DispatchQueue) {
        executer = SynchronizedExecuter(queue: queue)
        innerObservable = DefaultStatefulObservable(wrappedObservable.currentValue.value)
        self.wrappedObservable = wrappedObservable
    }

    public func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable {

        let innerDisposable = innerObservable.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable.add(startObserving())
        }

        return compositeDisposable
    }

    private func startObserving() -> Disposable {
        return wrappedObservable.observe { [weak self] value in
            self?.executer.sync { [weak self] in
                self?.innerObservable.emit(value)
            }
        }
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

}

internal struct UIObservableQueueInitializer {
    internal static let dispatchSpecificKey = DispatchSpecificKey<UInt8>()
    internal static let dispatchSpecificValue = UInt8.max

    static var initializeOnce: () = {
        DispatchQueue.main.setSpecific(key: dispatchSpecificKey,
                                       value: dispatchSpecificValue)
    }()
}

/// Heavily inspired by UIObservable from ReactiveSwift.
public final class UIObservable<SourceObservable: StatefulObservable>: StatefulObservable {
    public typealias ObservedValue = SourceObservable.ObservedValue

    public var currentValue: SynchronizedProperty<SourceObservable.ObservedValue> {
        return innerObservable.currentValue
    }

    private let wrappedObservable: SourceObservable
    private let innerObservable: DefaultStatefulObservable<ObservedValue>
    private let isObserved = SynchronizedMutableProperty(false)
    private let disposeBag = DisposeBag()

    // `inout` references do not guarantee atomicity. Use `UnsafeMutablePointer`
    // instead.
    //
    // https://lists.swift.org/pipermail/swift-users/Week-of-Mon-20161205/004147.html
    private let queueLength: UnsafeMutablePointer<Int32> = {
        let memory = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        memory.initialize(to: 0)
        return memory
    }()

    deinit {
        queueLength.deinitialize(count: 1)
        queueLength.deallocate()
    }

    /// Initializes `UIObservable`
    public init(_ wrappedObservable: SourceObservable) {
        /// This call is to ensure the main queue has been setup appropriately
        /// for `UIObservable`. It is only called once during the application
        /// lifetime, since Swift has a `dispatch_once` like mechanism to
        /// lazily initialize global variables and static variables.
        _ = UIObservableQueueInitializer.initializeOnce

        self.wrappedObservable = wrappedObservable
        self.innerObservable = DefaultStatefulObservable(wrappedObservable.currentValue.value)
    }

    public func observe(_ valuesOverTime: @escaping (SourceObservable.ObservedValue) -> Void) -> Disposable {

        let innerDisposable = innerObservable.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable.add(startObserving())
        }

        return compositeDisposable
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

    private func startObserving() -> Disposable {
        return wrappedObservable
            .observe { [weak self] value in
                guard let self = self else { return }

                let positionInQueue = self.enqueue()

                // If we're already running on the main queue, and there isn't work
                // already enqueued, we can skip scheduling and just execute directly.
                if positionInQueue == 1 && DispatchQueue.getSpecific(
                    key: UIObservableQueueInitializer.dispatchSpecificKey) ==
                        UIObservableQueueInitializer.dispatchSpecificValue {
                    self.innerObservable.emit(value)
                    self.dequeue()
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.innerObservable.emit(value)
                        self.dequeue()
                    }
                }
            }
    }

    private func dequeue() {
        OSAtomicDecrement32(queueLength)
    }

    private func enqueue() -> Int32 {
        return OSAtomicIncrement32(queueLength)
    }

}

/// Skips repeated values (distinct until changed).
public final class SkipRepeatsObservable<SourceValue>: StatefulObservable {
    public typealias ObservedValue = SourceValue

    public var currentValue: SynchronizedProperty<SourceValue> {
        return innerObservable.currentValue
    }

    private let lastValue: SynchronizedMutableProperty<SourceValue>
    private let innerObservable: DefaultStatefulObservable<SourceValue>
    private let sourceObservable: AnyStatefulObservable<SourceValue>
    private let isObserved = SynchronizedMutableProperty<Bool>(false)
    private let isEqual: (SourceValue, SourceValue) -> (Bool)

    public init(_ sourceObservable: AnyStatefulObservable<SourceValue>,
                isEqual: @escaping (SourceValue, SourceValue) -> (Bool)) {
        self.sourceObservable = sourceObservable
        self.isEqual = isEqual
        let initialValue = sourceObservable.currentValue.value
        self.lastValue = SynchronizedMutableProperty<SourceValue>(initialValue)
        self.innerObservable = DefaultStatefulObservable(initialValue)
    }

    public func observe(_ valuesOverTime: @escaping (SourceValue) -> Void) -> Disposable {

        let innerDisposable = innerObservable.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable += startObserving()
        }

        return compositeDisposable
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

    private func startObserving() -> Disposable {

        return sourceObservable.observe { [weak self] newValue in
            guard let self = self,
                self.isEqual(newValue, self.lastValue.value) == false else { return }

            self.lastValue.value = newValue
            self.innerObservable.emit(newValue)
        }
    }

}

public extension SkipRepeatsObservable where SourceValue : Equatable {

    convenience init(_ sourceObservable: AnyStatefulObservable<SourceValue>) {
        self.init(sourceObservable, isEqual: { lhs, rhs in return lhs == rhs })
    }
}
