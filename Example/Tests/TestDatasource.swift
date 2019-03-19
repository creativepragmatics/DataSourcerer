import Foundation
import DataSourcerer

internal extension ValueStream {

    internal init<Value, P: Parameters>(
        testStates states: [State<Value, P, TestStateError>],
        testError: TestStateError,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>) where ObservedValue == State<Value, P, TestStateError> {

        self.init(
            makeStatesWithClosure: { loadImpulse, sendState -> Disposable in
                if let state = states.first(where: { $0.loadImpulse == loadImpulse }) {
                    sendState(state)
                } else {
                    let errorState = State<Value, P, TestStateError>.error(
                        error: testError,
                        loadImpulse: loadImpulse,
                        fallbackValueBox: nil
                    )
                    sendState(errorState)
                }

                return VoidDisposable()
            },
            loadImpulseEmitter: loadImpulseEmitter
        )
    }

}

struct OneTwoThreeStringTestStates {

    public static var oneTwoThreeStringStates: [State<String, String, TestStateError>] = {
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
}
