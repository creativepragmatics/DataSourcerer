import Foundation

/// Retains the last emitted value of the included `Observable`.
/// Calling `observe(_)` returns the current or initial value
/// synchronously on the queue on which `observe(_)` is called.
/// After that, `sourceObservable`'s stream of values is forwarded.
///
/// Similar to ReactiveSwift.Property.
public final class ShareableValueStream<T_>: ObservableProtocol, Property {
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
