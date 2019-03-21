import Foundation
import DataSourcerer

internal extension ValueStream {

    internal init<Value, P: ResourceParams>(
        testStates states: [ResourceState<Value, P, TestStateError>],
        testError: TestStateError,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>) where ObservedValue == ResourceState<Value, P, TestStateError> {

        self.init(
            makeStatesWithClosure: { loadImpulse, sendState -> Disposable in
                if let state = states.first(where: { $0.loadImpulse == loadImpulse }) {
                    sendState(state)
                } else {
                    let errorState = ResourceState<Value, P, TestStateError>.error(
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

    public static var oneTwoThreeStringStates: [ResourceState<String, String, TestStateError>] = {
        return [
            ResourceState.value(valueBox: EquatableBox("1"),
                        loadImpulse: LoadImpulse(params: "1"),
                        fallbackError: nil),
            ResourceState.value(valueBox: EquatableBox("2"),
                        loadImpulse: LoadImpulse(params: "2"),
                        fallbackError: nil),
            ResourceState.value(valueBox: EquatableBox("3"),
                        loadImpulse: LoadImpulse(params: "3"),
                        fallbackError: nil)
        ]
    }()
}
