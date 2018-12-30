import Foundation

public protocol DatasourceStateMapperProtocol: ValueRetainingObservable {
    associatedtype MappedValue
    associatedtype Datasource: DatasourceProtocol
    typealias StateToMappedValue = (Datasource.DatasourceState) -> MappedValue

    var stateToMappedValue: StateToMappedValue { get set }
}

public final class DefaultDatasourceStateMapper<MappedValue, Datasource: DatasourceProtocol>
: ValueRetainingObservable {
    public typealias ObservedValue = MappedValue
    public typealias Value = Datasource.Value
    public typealias StateToMappedValue = (Datasource.DatasourceState) -> MappedValue

    public var disposable: Disposable?
    public var isObserved = SynchronizedMutableProperty(false)
    public var currentValue: SynchronizedProperty<ObservedValue> {
        return innerObservable.currentValue
    }
    private let _stateToMappedValue: SynchronizedMutableProperty<StateToMappedValue>
    public var stateToMappedValue: StateToMappedValue {
        get {
            return _stateToMappedValue.value
        }
        set {
            _stateToMappedValue.value = newValue
        }
    }

    public let innerObservable: DefaultObservable<MappedValue>
    public let datasource: Datasource

    public init(datasource: Datasource, stateToMappedValue: @escaping StateToMappedValue) {
        self.datasource = datasource
        self._stateToMappedValue = SynchronizedMutableProperty(stateToMappedValue)

        let initialItems = stateToMappedValue(datasource.currentValue.value)
        innerObservable = DefaultObservable(initialItems)
    }

    public func observe(_ valuesOverTime: @escaping (MappedValue) -> Void) -> Disposable {

        defer {
            let isFirstObservation = isObserved.set(true, ifCurrentValueIs: false)
            if isFirstObservation {
                startObserving()
            }
        }

        let disposable = innerObservable.observe(valuesOverTime)
        return CompositeDisposable(disposable, objectToRetain: self)
    }

    public func startObserving() {
        disposable = datasource.observe { [weak self] state in
            guard let self = self else { return }
            let items = self.stateToMappedValue(state)
            self.innerObservable.emit(items)
        }
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

    deinit {
        disposable?.dispose()
    }

}
