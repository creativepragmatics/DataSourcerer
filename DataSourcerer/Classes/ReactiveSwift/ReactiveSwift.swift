import Foundation
import ReactiveSwift
import Result

public extension Datasource {

    init(
        stateSignalProducer: @escaping (LoadImpulse<P>) -> SignalProducer<ObservedState, NoError>,
        mapErrorString: @escaping (ErrorString) -> E,
        cacheBehavior: CacheBehavior,
        loadImpulseBehavior: LoadImpulseBehavior
        ) {

        let loadImpulseEmitter = loadImpulseBehavior.loadImpulseEmitter

        let states = ValueStream<ObservedState>(
            signalProducer: stateSignalProducer,
            loadImpulseEmitter: loadImpulseEmitter.any
            )
            .rememberLatestSuccessAndError()

        let cachedStates = cacheBehavior
            .apply(on: states.any,
                   loadImpulseEmitter: loadImpulseEmitter)
            .skipRepeats()
            .observeOnUIThread()

        let shareableCachedStates = cachedStates.shareable(initialValue: .notReady)

        self.init(shareableCachedStates, loadImpulseEmitter: loadImpulseEmitter)
    }

    /// `valueSignalProducer` sends LoadImpulse<P> besides the Value because
    /// the impulse or parameters can change while a request is being made,
    /// e.g. when a token which is part of parameters is refreshed.
    init(
        valueSignalProducer: @escaping (LoadImpulse<P>)
            -> SignalProducer<(Value, LoadImpulse<P>), E>,
        mapErrorString: @escaping (ErrorString) -> E,
        cacheBehavior: CacheBehavior,
        loadImpulseBehavior: LoadImpulseBehavior
        ) {

        self.init(
            stateSignalProducer: { loadImpulse
                -> SignalProducer<ResourceState<Value, P, E>, NoError> in

                let initial = SignalProducer<ResourceState<Value, P, E>, NoError>(
                    value: ResourceState.loading(
                        loadImpulse: loadImpulse,
                        fallbackValueBox: nil,
                        fallbackError: nil
                    )
                )

                let producer = valueSignalProducer(loadImpulse)
                let successOrError = producer
                    .map { value, loadImpulse in
                        return ResourceState<Value, P, E>
                            .value(
                                valueBox: EquatableBox<Value>(value),
                                loadImpulse: loadImpulse,
                                fallbackError: nil
                            )
                    }
                    .flatMapError { error -> SignalProducer<ResourceState<Value, P, E>, NoError> in
                        return SignalProducer(
                            value: ResourceState<Value, P, E>
                                .error(error: error, loadImpulse: loadImpulse, fallbackValueBox: nil
                            )
                        )
                    }
                return initial.concat(successOrError)
            },
            mapErrorString: mapErrorString,
            cacheBehavior: cacheBehavior,
            loadImpulseBehavior: loadImpulseBehavior
        )
    }
    
}

public extension ValueStream {

    /// Initializes a ValueStream with a ReactiveSwift.SignalProducer.
    init<StateValue, P: ResourceParams, E: ResourceError>(
        signalProducer: @escaping (LoadImpulse<P>) -> SignalProducer<ObservedValue, NoError>,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>
        ) where ObservedValue == ResourceState<StateValue, P, E> {

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

public extension ShareableValueStream {

    /// Initializes a ValueStream with a ReactiveSwift.SignalProducer.
    var reactiveSwiftProperty: ReactiveSwift.Property<ObservedValue> {

        let signalProducer = SignalProducer<ObservedValue, NoError> { observer, lifetime in

            let dataSourcererDisposable = self.skip(first: 1)
                .observe { value in
                    observer.send(value: value)
            }

            lifetime += ReactiveSwift.AnyDisposable {
                dataSourcererDisposable.dispose()
            }
        }

        return ReactiveSwift.Property(initial: self.value, then: signalProducer)
    }

}
