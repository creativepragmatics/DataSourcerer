import Foundation

public final class BroadcastObservable<ObservedValue_>: ObservableProtocol {
    public typealias ObservedValue = ObservedValue_

    private let observers = SynchronizedMutableProperty([Int: ValuesOverTime]())

    public init() {}

    public func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable {

        let uniqueKey = Int(arc4random_uniform(10_000))
        observers.modify {
            $0[uniqueKey] = valuesOverTime
        }

        let disposable = ActionDisposable {
            self.observers.modify { $0.removeValue(forKey: uniqueKey) }
        }

        return CompositeDisposable(disposable, objectToRetain: self)
    }

    public func emit(_ value: ObservedValue) {

        observers.value.values.forEach { valuesOverTime in
            valuesOverTime(value)
        }
    }
}
