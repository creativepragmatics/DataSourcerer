import Foundation

public extension DatasourceProtocol {

    func map<TransformedValue>(_ transform: @escaping (ObservedValue) -> (TransformedValue))
        -> DatasourceMapped<ObservedValue, TransformedValue> {

        return DatasourceMapped(self.any, transform: transform)
    }

    func observe(on queue: DispatchQueue) -> DispatchQueueDatasource<Self> {
        return DispatchQueueDatasource(self, queue: queue)
    }

    func observeOnUIThread() -> UIDatasource<Self> {
        return UIDatasource(self)
    }

    func skipRepeats(_ isEqual:@escaping (_ lhs: ObservedValue, _ rhs: ObservedValue) -> Bool)
        -> SkipRepeatsDatasource<ObservedValue> {
            return SkipRepeatsDatasource(self.any, isEqual: isEqual)
    }

}

public extension DatasourceProtocol where ObservedValue: Equatable {

    func skipRepeats() -> SkipRepeatsDatasource<ObservedValue> {
            return SkipRepeatsDatasource(self.any)
    }

}

public final class DatasourceMapped<SourceValue, TransformedValue>: DatasourceProtocol {
    public typealias ObservedValue = TransformedValue

    public var currentValue: SynchronizedProperty<TransformedValue> {
        return coreDatasource.currentValue
    }

    private let transform: (SourceValue) -> (TransformedValue)
    private let coreDatasource: SimpleDatasource<TransformedValue>
    private let sourceDatasource: AnyDatasource<SourceValue>
    private let isObserved = SynchronizedMutableProperty<Bool>(false)

    init(_ sourceDatasource: AnyDatasource<SourceValue>,
         transform: @escaping (SourceValue) -> (TransformedValue)) {
        self.sourceDatasource = sourceDatasource
        self.transform = transform
        let initialValue = transform(sourceDatasource.currentValue.value)
        self.coreDatasource = SimpleDatasource(initialValue)
    }

    public func observe(_ valuesOverTime: @escaping (TransformedValue) -> Void) -> Disposable {

        let innerDisposable = coreDatasource.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable.add(startObserving())
        }

        return compositeDisposable
    }

    public func removeObserver(with key: Int) {
        coreDatasource.removeObserver(with: key)
    }

    private func startObserving() -> Disposable {

        return sourceDatasource.observe { [weak self] sourceValue in
            guard let self = self else { return }
            self.coreDatasource.emit(self.transform(sourceValue))
        }
    }

}

/// Sends values only on the defined thread.
public final class DispatchQueueDatasource<SourceDatasource: DatasourceProtocol>: DatasourceProtocol {

    public typealias ObservedValue = SourceDatasource.ObservedValue

    private let sourceDatasource: SourceDatasource
    private let coreDatasource: SimpleDatasource<ObservedValue>
    private let executer: SynchronizedExecuter
    private let isObserved = SynchronizedMutableProperty(false)

    public var currentValue: SynchronizedProperty<ObservedValue> {
        return coreDatasource.currentValue
    }

    public init(_ sourceDatasource: SourceDatasource, queue: DispatchQueue) {
        executer = SynchronizedExecuter(queue: queue)
        coreDatasource = SimpleDatasource(sourceDatasource.currentValue.value)
        self.sourceDatasource = sourceDatasource
    }

    public func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable {

        let innerDisposable = coreDatasource.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable.add(startObserving())
        }

        return compositeDisposable
    }

    private func startObserving() -> Disposable {
        return sourceDatasource.observe { [weak self] value in
            self?.executer.sync { [weak self] in
                self?.coreDatasource.emit(value)
            }
        }
    }

    public func removeObserver(with key: Int) {
        coreDatasource.removeObserver(with: key)
    }

}

internal struct UIDatasourceQueueInitializer {
    internal static let dispatchSpecificKey = DispatchSpecificKey<UInt8>()
    internal static let dispatchSpecificValue = UInt8.max

    static var initializeOnce: () = {
        DispatchQueue.main.setSpecific(key: dispatchSpecificKey,
                                       value: dispatchSpecificValue)
    }()
}

/// Heavily inspired by UIScheduler from ReactiveSwift.
public final class UIDatasource<SourceDatasource: DatasourceProtocol>: DatasourceProtocol {
    public typealias ObservedValue = SourceDatasource.ObservedValue

    public var currentValue: SynchronizedProperty<SourceDatasource.ObservedValue> {
        return coreDatasource.currentValue
    }

    private let sourceDatasource: SourceDatasource
    private let coreDatasource: SimpleDatasource<ObservedValue>
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

    /// Initializes `UIDatasource`
    public init(_ sourceDatasource: SourceDatasource) {
        /// This call is to ensure the main queue has been setup appropriately
        /// for `UIDatasource`. It is only called once during the application
        /// lifetime, since Swift has a `dispatch_once` like mechanism to
        /// lazily initialize global variables and static variables.
        _ = UIDatasourceQueueInitializer.initializeOnce

        self.sourceDatasource = sourceDatasource
        self.coreDatasource = SimpleDatasource(sourceDatasource.currentValue.value)
    }

    public func observe(_ valuesOverTime: @escaping (SourceDatasource.ObservedValue) -> Void) -> Disposable {

        let innerDisposable = coreDatasource.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable.add(startObserving())
        }

        return compositeDisposable
    }

    public func removeObserver(with key: Int) {
        coreDatasource.removeObserver(with: key)
    }

    private func startObserving() -> Disposable {
        return sourceDatasource
            .observe { [weak self] value in
                guard let self = self else { return }

                let positionInQueue = self.enqueue()

                // If we're already running on the main queue, and there isn't work
                // already enqueued, we can skip scheduling and just execute directly.
                if positionInQueue == 1 && DispatchQueue.getSpecific(
                    key: UIDatasourceQueueInitializer.dispatchSpecificKey) ==
                        UIDatasourceQueueInitializer.dispatchSpecificValue {
                    self.coreDatasource.emit(value)
                    self.dequeue()
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.coreDatasource.emit(value)
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
public final class SkipRepeatsDatasource<SourceValue>: DatasourceProtocol {
    public typealias ObservedValue = SourceValue

    public var currentValue: SynchronizedProperty<SourceValue> {
        return coreDatasource.currentValue
    }

    private let lastValue: SynchronizedMutableProperty<SourceValue>
    private let coreDatasource: SimpleDatasource<SourceValue>
    private let sourceDatasource: AnyDatasource<SourceValue>
    private let isObserved = SynchronizedMutableProperty<Bool>(false)
    private let isEqual: (SourceValue, SourceValue) -> (Bool)

    public init(_ sourceDatasource: AnyDatasource<SourceValue>,
                isEqual: @escaping (SourceValue, SourceValue) -> (Bool)) {
        self.sourceDatasource = sourceDatasource
        self.isEqual = isEqual
        let initialValue = sourceDatasource.currentValue.value
        self.lastValue = SynchronizedMutableProperty<SourceValue>(initialValue)
        self.coreDatasource = SimpleDatasource(initialValue)
    }

    public func observe(_ valuesOverTime: @escaping (SourceValue) -> Void) -> Disposable {

        let innerDisposable = coreDatasource.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable += startObserving()
        }

        return compositeDisposable
    }

    public func removeObserver(with key: Int) {
        coreDatasource.removeObserver(with: key)
    }

    private func startObserving() -> Disposable {

        return sourceDatasource.observe { [weak self] newValue in
            guard let self = self,
                self.isEqual(newValue, self.lastValue.value) == false else { return }

            self.lastValue.value = newValue
            self.coreDatasource.emit(newValue)
        }
    }

}

public extension SkipRepeatsDatasource where SourceValue : Equatable {

    convenience init(_ sourceDatasource: AnyDatasource<SourceValue>) {
        self.init(sourceDatasource, isEqual: { lhs, rhs in return lhs == rhs })
    }
}
