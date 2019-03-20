import Foundation
import ReactiveSwift
import Result

public extension Datasource {

    init(
        signalProducer: @escaping (LoadImpulse<P>) -> SignalProducer<ObservedState, NoError>,
        mapErrorString: @escaping (ErrorString) -> E,
        cacheBehavior: CacheBehavior<Value, P, E>,
        loadImpulseBehavior: LoadImpulseBehavior<P>
        ) {

        let loadImpulseEmitter = loadImpulseBehavior.loadImpulseEmitter

        let states = ValueStream<ObservedState>(
            signalProducer: signalProducer,
            loadImpulseEmitter: loadImpulseEmitter.any
            )
            .retainLastResultState()

        let cachedStates = cacheBehavior
            .apply(on: states.any,
                   loadImpulseEmitter: loadImpulseEmitter)
            .skipRepeats()
            .observeOnUIThread()

        let shareableCachedStates = cachedStates.shareable(initialValue: .notReady)

        self.init(shareableCachedStates, loadImpulseEmitter: loadImpulseEmitter)
    }
}

public extension ValueStream {

    /// Initializes a ValueStream with a ReactiveSwift.SignalProducer.
    init<StateValue, P: Parameters, E: StateError>(
        signalProducer: @escaping (LoadImpulse<P>) -> SignalProducer<ObservedValue, NoError>,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>
        ) where ObservedValue == State<StateValue, P, E> {

        self.init { sendState, disposable in

            disposable += loadImpulseEmitter.observe { loadImpulse in

                let reactiveSwiftDisposable = signalProducer(loadImpulse)
                    .start { event in
                        switch event {
                        case let .value(state):
                            sendState(state)
                        case .completed, .interrupted, .failed:
                            break
                        }
                    }

                disposable += ActionDisposable {
                    reactiveSwiftDisposable.dispose()
                }
            }
        }
    }

}
