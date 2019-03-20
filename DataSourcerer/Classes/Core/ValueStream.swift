import Foundation

/// Provides an observable stream of values.
///
/// Will only start work after `observe(_)` is first called.
///
/// Analogy to ReactiveSwift: ValueStreams are like SignalProducers,
/// which are "cold" (no work performed) until they are started.
/// SignalProducer.init(_ startHandler) is very similar to
/// ValueStream.init(_ observeHandler).
///
/// Analogy to RxSwift/ReactiveX: Insert example :)
public struct ValueStream<Value>: ObservableProtocol {
    public typealias ObservedValue = Value
    public typealias ValuesOverTime = (ObservedValue) -> Void
    public typealias ObserveHandler = (@escaping ValuesOverTime, CompositeDisposable) -> Void

    private let observeHandler: ObserveHandler

    public init(_ observeHandler: @escaping ObserveHandler) {
        self.observeHandler = observeHandler
    }

    public func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable {

        let disposable = CompositeDisposable()
        observeHandler(valuesOverTime, disposable)
        return disposable
    }
}

// MARK: Closure support

public extension ValueStream {

    /// Initializes a ValueStream with a closure that generates
    /// `State`s.
    init<Value, P: ResourceParams, E: ResourceError>(
        makeStatesWithClosure
        generateState: @escaping (LoadImpulse<P>, @escaping ValuesOverTime) -> Disposable,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>
        ) where ObservedValue == ResourceState<Value, P, E> {

        self.init { sendState, disposable in

            disposable += loadImpulseEmitter.observe { loadImpulse in
                disposable += generateState(loadImpulse, sendState)
            }
        }
    }
}

// MARK: Load from ResourceStatePersister

public extension ValueStream {

    /// Sends a persisted state from `persister`, every time
    /// `loadImpulseEmitter` sends an impulse. If an error occurs
    /// while loading (e.g. deserialization error), `cacheLoadError`
    /// is sent instead.
    init<Value, P: ResourceParams, E: ResourceError>(
        loadStatesFromPersister persister: AnyResourceStatePersister<Value, P, E>,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
        cacheLoadError: E
        ) where ObservedValue == ResourceState<Value, P, E> {

        self.init { sendState, disposable in

            disposable += loadImpulseEmitter.observe { loadImpulse in
                guard let cached = persister.load(loadImpulse.parameters) else {
                    let error = ResourceState<Value, P, E>.error(error: cacheLoadError,
                                                                 loadImpulse: loadImpulse,
                                                                 fallbackValueBox: nil)
                    sendState(error)
                    return
                }

                sendState(cached)
            }
        }
    }
}
