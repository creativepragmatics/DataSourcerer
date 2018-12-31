import Foundation

public extension StatefulObservable {

    func map<TransformedValue>(_ transform: @escaping (ObservedValue) -> (TransformedValue))
        -> StatefulObservableMapped<ObservedValue, TransformedValue> {

        return StatefulObservableMapped(self.any, transform: transform)
    }

    func observe(on queue: DispatchQueue) -> DispatchQueueObservable<Self> {
        return DispatchQueueObservable(self, queue: queue)
    }

    func observeOnUIThread() -> DispatchQueueObservable<Self> {
        return DispatchQueueObservable(self, queue: DispatchQueue.main)
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
    private let disposeBag = DisposeBag()

    init(_ sourceObservable: AnyStatefulObservable<SourceValue>,
         transform: @escaping (SourceValue) -> (TransformedValue)) {
        self.sourceObservable = sourceObservable
        self.transform = transform
        let initialValue = transform(sourceObservable.currentValue.value)
        self.innerObservable = DefaultStatefulObservable(initialValue)
    }

    public func observe(_ valuesOverTime: @escaping (TransformedValue) -> Void) -> Disposable {

        defer {
            let isFirstObservation = isObserved.set(true, ifCurrentValueIs: false)
            if isFirstObservation {
                startObserving()
            }
        }

        valuesOverTime(transform(sourceObservable.currentValue.value))

        let disposable = innerObservable.observe(valuesOverTime)
        return CompositeDisposable(disposable, objectToRetain: self)
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

    private func startObserving() {

        sourceObservable.observe { [weak self] sourceValue in
            guard let self = self else { return }
            self.innerObservable.emit(self.transform(sourceValue))
        }.disposed(by: disposeBag)
    }

}

/// Sends values only on the defined thread.
public final class DispatchQueueObservable<SourceObservable: StatefulObservable>: StatefulObservable {

    public typealias ObservedValue = SourceObservable.ObservedValue

    private let wrappedObservable: SourceObservable
    private let innerObservable: DefaultStatefulObservable<ObservedValue>
    private let disposeBag = DisposeBag()
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

        defer {
            let isFirstObservation = isObserved.set(true, ifCurrentValueIs: false)
            if isFirstObservation {
                startObserving()
            }
        }

        let innerDisposable = innerObservable.observe(valuesOverTime)
        return CompositeDisposable(innerDisposable, objectToRetain: self)
    }

    private func startObserving() {
        wrappedObservable
            .observe { [weak self] value in
                self?.executer.sync { [weak self] in
                    self?.innerObservable.emit(value)
                }
            }
            .disposed(by: disposeBag)
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
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
    private let disposeBag = DisposeBag()

    public init(_ sourceObservable: AnyStatefulObservable<SourceValue>,
                isEqual: @escaping (SourceValue, SourceValue) -> (Bool)) {
        self.sourceObservable = sourceObservable
        self.isEqual = isEqual
        let initialValue = sourceObservable.currentValue.value
        self.lastValue = SynchronizedMutableProperty<SourceValue>(initialValue)
        self.innerObservable = DefaultStatefulObservable(initialValue)
    }

    public func observe(_ valuesOverTime: @escaping (SourceValue) -> Void) -> Disposable {

        defer {
            let isFirstObservation = isObserved.set(true, ifCurrentValueIs: false)
            if isFirstObservation {
                startObserving()
            }
        }

        valuesOverTime(sourceObservable.currentValue.value)

        let disposable = innerObservable.observe(valuesOverTime)
        return CompositeDisposable(disposable, objectToRetain: self)
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

    private func startObserving() {

        sourceObservable.observe { [weak self] newValue in
            guard let self = self,
                self.isEqual(newValue, self.lastValue.value) == false else { return }

            self.lastValue.value = newValue
            self.innerObservable.emit(newValue)
        }.disposed(by: disposeBag)
    }

}

public extension SkipRepeatsObservable where SourceValue : Equatable {

    convenience init(_ sourceObservable: AnyStatefulObservable<SourceValue>) {
        self.init(sourceObservable, isEqual: { lhs, rhs in return lhs == rhs })
    }
}
