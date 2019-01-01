import Foundation

public protocol DatasourceStateMapperProtocol: StatefulObservable {
    associatedtype MappedValue
    associatedtype Datasource: DatasourceProtocol
    typealias StateToMappedValue = (Datasource.DatasourceState) -> MappedValue

    var stateToMappedValue: StateToMappedValue { get set }
}

public final class DefaultDatasourceStateMapper<MappedValue, Datasource: DatasourceProtocol>
: StatefulObservable {
    public typealias ObservedValue = MappedValue
    public typealias Value = Datasource.Value
    public typealias StateToMappedValue = (Datasource.DatasourceState) -> MappedValue

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

    public let innerObservable: DefaultStatefulObservable<MappedValue>
    public let datasource: Datasource

    public init(datasource: Datasource, stateToMappedValue: @escaping StateToMappedValue) {
        self.datasource = datasource
        self._stateToMappedValue = SynchronizedMutableProperty(stateToMappedValue)

        let initialItems = stateToMappedValue(datasource.currentValue.value)
        innerObservable = DefaultStatefulObservable(initialItems)
    }

    public func observe(_ valuesOverTime: @escaping (MappedValue) -> Void) -> Disposable {

        let innerDisposable = innerObservable.observe(valuesOverTime)
        let compositeDisposable = CompositeDisposable(innerDisposable, objectToRetain: self)

        if isObserved.set(true, ifCurrentValueIs: false) {
            compositeDisposable.add(startObserving())
        }

        return compositeDisposable
    }

    public func startObserving() -> Disposable {
        return datasource.observe { [weak self] state in
            guard let self = self else { return }
            let items = self.stateToMappedValue(state)
            self.innerObservable.emit(items)
        }
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

}
