import Foundation
import DataSourcerer

open class TestDatasource<Value_, P_: Parameters & Hashable, E_: DatasourceError>: DatasourceProtocol {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias ObservedValue = DatasourceState

    public let sendsFirstStateSynchronously = true
    public let loadImpulseEmitter: AnyLoadImpulseEmitter<P>
    public var currentValue: SynchronizedProperty<DatasourceState> {
        return innerDatasource.currentValue
    }
    private let innerDatasource: ClosureDatasource<Value, P, E>

    private let disposeBag = DisposeBag()

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

    private let innerObservable = InnerStateObservable<Value, P, E>(.notReady)

    init(loadImpulseEmitter: AnyLoadImpulseEmitter<P>, states: [State<Value, P, E>], error: E) {
        self.loadImpulseEmitter = loadImpulseEmitter

        self.innerDatasource = ClosureDatasource.init(loadImpulseEmitter: loadImpulseEmitter, { (loadImpulse, send) in
            let state = states.first(where: { $0.loadImpulse == loadImpulse })
                ?? DatasourceState.error(error: error, loadImpulse: loadImpulse, fallbackValueBox: nil)
            send(state)
            return VoidDisposable()
        })
    }

    public func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable {

        return innerDatasource.observe(valuesOverTime)
    }

}

class OneTwoThreeStringTestDatasource: TestDatasource<String, String, TestDatasourceError> {

    public static let initialRequestParameter = "1"

    public static let states: [OneTwoThreeStringTestDatasource.DatasourceState] = {
        return [
            State.value(valueBox: EquatableBox("1"),
                        loadImpulse: LoadImpulse(parameters: "1"),
                        fallbackError: nil),
            State.value(valueBox: EquatableBox("2"),
                        loadImpulse: LoadImpulse(parameters: "2"),
                        fallbackError: nil),
            State.value(valueBox: EquatableBox("3"),
                        loadImpulse: LoadImpulse(parameters: "3"),
                        fallbackError: nil)
        ]
    }()

    init(loadImpulseEmitter: AnyLoadImpulseEmitter<P>) {
        super.init(loadImpulseEmitter: loadImpulseEmitter, states: OneTwoThreeStringTestDatasource.states, error: TestDatasourceError.unknown(description: "Value not in values parameter"))
    }
}
