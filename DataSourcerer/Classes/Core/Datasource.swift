import Foundation

/// Provides an observable stream of values.
///
/// Will only start work after `observe(_)` is first called.
///
/// Analogy to ReactiveSwift: Datasources are like SignalProducers,
/// which are "cold" (no work performed) until they are started.
/// SignalProducer.init(_ startHandler) is very similar to
/// Datasource.init(_ observeHandler).
///
/// Analogy to RxSwift/ReactiveX: Insert example :)
public struct Datasource<Value>: ObservableProtocol {
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

public extension Datasource {

    /// Initializes a datasource with a closure that generates
    /// `State`s.
    init<Value, P: Parameters, E: StateError>(
        makeStatesWithClosure
        generateState: @escaping (LoadImpulse<P>, @escaping ValuesOverTime) -> Disposable,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>
        ) where ObservedValue == State<Value, P, E> {

        self.init { sendState, disposable in

            disposable += loadImpulseEmitter.observe { loadImpulse in
                disposable += generateState(loadImpulse, sendState)
            }
        }
    }
}

// MARK: Load from StatePersister

public extension Datasource {

    /// Sends a persisted state from `persister`, every time
    /// `loadImpulseEmitter` sends an impulse. If an error occurs
    /// while loading (e.g. deserialization error), `cacheLoadError`
    /// is sent instead.
    init<Value, P: Parameters, E: StateError>(
        loadStatesFromPersister persister: AnyStatePersister<Value, P, E>,
        loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
        cacheLoadError: E
        ) where ObservedValue == State<Value, P, E> {

        self.init { sendState, disposable in

            disposable += loadImpulseEmitter.observe { loadImpulse in
                guard let cached = persister.load(loadImpulse.parameters) else {
                    let error = State<Value, P, E>.error(error: cacheLoadError,
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
