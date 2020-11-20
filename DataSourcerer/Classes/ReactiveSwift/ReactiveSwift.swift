import Foundation
import ReactiveSwift

public extension Datasource {

    init(
        stateSignalProducer: @escaping (LoadImpulse<P>) -> SignalProducer<ObservedState, Never>,
        mapErrorString: @escaping (ErrorString) -> E,
        cacheBehavior: CacheBehavior,
        loadImpulseBehavior: LoadImpulseBehavior
        ) {

        let loadImpulseEmitter = loadImpulseBehavior.loadImpulseEmitter

        let states = ValueStream<ObservedState>(
            signalProducer: stateSignalProducer,
            loadImpulseEmitter: loadImpulseEmitter.any
            )
            .rememberLatestSuccessAndError(
                behavior: RememberLatestSuccessAndErrorBehavior(
                    preferFallbackValueOverFallbackError: true
                )
            )

        let cachedStates = cacheBehavior
            .apply(on: states.any,
                   loadImpulseEmitter: loadImpulseEmitter)
            .skipRepeats()
            .observeOnUIThread()

        let shareableCachedStates = cachedStates.shareable(initialValue: .notReady)

        self.init(shareableCachedStates, loadImpulseEmitter: loadImpulseEmitter)
    }

    /// `valueSignalAndLoadImpulseProducer` sends LoadImpulse<P> besides the Value because
    /// the impulse or parameters can change while a request is being made,
    /// e.g. when a token which is part of parameters is refreshed.
    init(
        valueSignalAndLoadImpulseProducer: @escaping (LoadImpulse<P>)
        -> SignalProducer<(Value, LoadImpulse<P>), E>,
        mapErrorString: @escaping (ErrorString) -> E,
        cacheBehavior: CacheBehavior,
        loadImpulseBehavior: LoadImpulseBehavior,
        initialLoadingState: ((LoadImpulse<P>) -> ResourceState<Value, P, E>)? = nil
        ) {

        self.init(
            stateSignalProducer: { loadImpulse
                -> SignalProducer<ResourceState<Value, P, E>, Never> in

                let initial = SignalProducer<ResourceState<Value, P, E>, Never>(
                    value: initialLoadingState?(loadImpulse) ?? ResourceState.loading(
                        loadImpulse: loadImpulse,
                        fallbackValueBox: nil,
                        fallbackError: nil
                    )
                )

                let producer = valueSignalAndLoadImpulseProducer(loadImpulse)
                let successOrError = producer
                    .map { value, loadImpulse in
                        return ResourceState<Value, P, E>
                            .value(
                                valueBox: EquatableBox<Value>(value),
                                loadImpulse: loadImpulse,
                                fallbackError: nil
                            )
                    }
                    .flatMapError { error -> SignalProducer<ResourceState<Value, P, E>, Never> in
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

    init(signalProducer: SignalProducer<ObservedValue, Never>) {

        self.init { sendValue, disposable in
            let reactiveSwiftDisposable = signalProducer.startWithValues { value in
                sendValue(value)
            }

            disposable += ActionDisposable {
                reactiveSwiftDisposable.dispose()
            }
        }
    }

    /// Initializes a ValueStream with a ReactiveSwift.SignalProducer.
    init<StateValue, P: ResourceParams, E: ResourceError>(
        signalProducer: @escaping (LoadImpulse<P>) -> SignalProducer<ObservedValue, Never>,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>
        ) where ObservedValue == ResourceState<StateValue, P, E> {

        self.init { sendState, disposable in

            disposable += loadImpulseEmitter
                .flatMapLatest { loadImpulse -> AnyObservable<ObservedValue> in
                    return ValueStream(signalProducer: signalProducer(loadImpulse)).any
                }
                .observe { state in
                    sendState(state)
                }
        }
    }

}

public extension ShareableValueStream {

    /// Initializes a ValueStream with a ReactiveSwift.SignalProducer.
    var reactiveSwiftProperty: ReactiveSwift.Property<ObservedValue> {

        let signalProducer = SignalProducer<ObservedValue, Never> { observer, lifetime in

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

public extension AnyObservable {

    var reactiveSwiftSignalProducer: ReactiveSwift.SignalProducer<ObservedValue, Never> {

        return SignalProducer<ObservedValue, Never> { observer, lifetime in

            let dataSourcererDisposable = self.observe { loadImpulse in
                observer.send(value: loadImpulse)
            }

            lifetime += ReactiveSwift.AnyDisposable {
                dataSourcererDisposable.dispose()
            }
        }
    }
}
