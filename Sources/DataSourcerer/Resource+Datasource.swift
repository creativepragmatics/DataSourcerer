import Foundation
import ReactiveSwift

public extension Resource where Failure: Equatable {

    /// A Datasource hosts Resource states and a load impulse emitter.
    /// Whenever a load impulse is emitted, the Resource state is
    /// expected to change (e.g. by loading from an API or other
    /// off-memory location).
    struct Datasource {
        public let loadImpulseEmitter: Resource.LoadImpulseEmitter
        public let state: Property<Resource.State>

        public init(
            loadImpulseEmitter: Resource.LoadImpulseEmitter,
            state: Property<Resource.State>
        ) {
            self.loadImpulseEmitter = loadImpulseEmitter
            self.state = state
        }
    }
}

public extension Resource.Datasource {

    /// Convenience method for getting the first Resource state (no matter
    /// whether a value is available), and performing a full refresh if no
    /// value is currently available.
    func firstStateAndRefreshIfNoValue(
        query: Resource.QueryType,
        emitTime: Resource.LoadImpulseEmitter.EmitTime = .now
    ) -> SignalProducer<Resource.State, Never> {
        state.producer
            .take(first: 1)
            .on(value: { [loadImpulseEmitter] in
                if $0.value?.value == nil {
                    let loadImpulse = Resource.LoadImpulse(
                        query: query,
                        type: .init(
                            context: .fullRefresh,
                            actor: .system,
                            showLoadingIndicator: true
                        )
                    )
                    loadImpulseEmitter.emit(loadImpulse, emitTime)
                }
            })
    }

    /// Refreshes the Resource by sending a load impulse.
    /// - Parameters:
    ///   - query: The query to be used for the refresh.
    ///   - skipIfSuccessfullyLoaded: If true, the refresh is not performed
    ///      if a value and **no** error is available.
    /// - Returns: A SignalProducer which sends a value when the refreshing
    ///      has ended.
    func refresh(
        query: Resource.QueryType,
        skipIfSuccessfullyLoaded: Bool
    ) -> SignalProducer<RefreshingEnded, Never> {
        let skip: Bool = {
            guard skipIfSuccessfullyLoaded else { return false }
            switch state.value.provisioningState {
            case .loading, .notReady:
                return false
            case .result:
                return state.value.value?.value != nil &&
                    state.value.error == nil
            }
        }()
        guard !skip else { return SignalProducer(value: ()) }

        return SignalProducer { [state, loadImpulseEmitter] observer, lifetime in

            let loadImpulse = Resource.LoadImpulse(
                query: query,
                type: .init(
                    context: .fullRefresh,
                    actor: .user,
                    showLoadingIndicator: true
                )
            )
            loadImpulseEmitter.emit(loadImpulse, .now)

            switch state.value.provisioningState {
            case .loading, .notReady:
                lifetime += state
                    .signal
                    .flatMap(.latest) { state -> SignalProducer<RefreshingEnded, Never> in
                        switch state.provisioningState {
                        case .result:
                            return .init(value: ())
                        case .loading, .notReady:
                            return .empty
                        }
                    }
                    .take(first: 1)
                    .observe(observer)
            case .result:
                observer.send(value: ())
                observer.sendCompleted()
            }
        }
    }

    /// Sends `Void` whenever a `.result` provisioning state
    /// is reached.
    func loadingEnded() -> Signal<Void, Never> {
        state.signal
            .filter { state in
                switch state.provisioningState {
                case .result:
                    return true
                case .notReady, .loading:
                    return false
                }
            }
            .map(value: ())
    }
}

public extension Resource.Datasource where Query == NoQuery {

    /// Convenience method for getting the first Resource state (no matter
    /// whether a value is available), and performing a full refresh if no
    /// value is currently available.
    func firstStateAndRefreshIfNoValue() -> SignalProducer<Resource.State, Never> {
        firstStateAndRefreshIfNoValue(query: NoQuery())
    }

    /// Refreshes the Resource by sending a load impulse.
    /// - Parameters:
    ///   - skipIfSuccessfullyLoaded: If true, the refresh is not performed
    ///      if a value and **no** error is available.
    /// - Returns: A SignalProducer which sends a value when the refreshing
    ///      has ended.
    func refresh(skipIfSuccessfullyLoaded: Bool) -> SignalProducer<RefreshingEnded, Never> {
        refresh(query: NoQuery(), skipIfSuccessfullyLoaded: skipIfSuccessfullyLoaded)
    }
}

public extension Resource.Datasource where Failure: Error {

    /// Opinionated convenience initializer for a Datasource.
    ///
    /// - Parameters:
    ///   - makeApiRequest: Maker for an API (or otherwise off-memory resource) request
    ///   - cache: (Optional) cache in which to temporarily retain resources fetched from API
    ///   - initialLoadImpulse: The initial load impulse for the API request. The impulse is
    ///       sent synchronously, before this initializer returns. The resource state's
    ///       provisioningState might therefore be .loading right after this returns, if
    ///       initialLoadImpulse is set. Set to `nil` if the Datasource should wait with
    ///       loading until `additionalLoadImpulses` sends a load impulse, or
    ///       `refresh(skipIfResultAvailable:)` is called.
    ///   - additionalLoadImpulses: SignalProducer sending additional load impulses. Use this
    ///       to send load impulses which are not sent imperatively via
    ///       `refresh(skipIfResultAvailable:)`.
    ///   - combinePreviousStateMode: Determine whether the Datasource should carry over
    ///       success and/or error values from the current resource state to the next resource
    ///       state. If set to `.none`, the result will be that e.g. a list displaying the
    ///       resource state might show an empty list whenever the provisioningState
    ///       switches to `loading`. If set to `.combine()`, the same list would show
    ///       the last success or error state's value.
    ///       See `SignalProducer.combinePrevious(preferFallbackValueOverFallbackError:)`
    ///       for more documentation.
    init(
        makeApiRequest: @escaping (Resource.LoadImpulse)
            -> SignalProducer<Resource.ValueType, Failure>,
        cache: Resource.Cache?,
        initialLoadImpulse: Resource.LoadImpulse?,
        additionalLoadImpulses: SignalProducer<Resource.LoadImpulse, Never> = .never,
        combinePreviousStateMode: CombinePreviousStateMode =
            .combine(preferFallbackValueOverFallbackError: true)
    ) {
        let pipe = Signal<Resource.LoadImpulse, Never>.pipe()
        var loadImpulses = pipe.output.producer
            .merge(with: additionalLoadImpulses)
        if let initialLoadImpulse = initialLoadImpulse {
            loadImpulses = loadImpulses.prefix(value: initialLoadImpulse)
        }

        let loadImpulseEmitter = Resource.LoadImpulseEmitter(
            loadImpulses: loadImpulses,
            emit: { loadImpulse, emitTime in
                switch emitTime {
                case .now:
                    pipe.input.send(value: loadImpulse)
                case let .nowAsync(queue):
                    queue.async {
                        pipe.input.send(value: loadImpulse)
                    }
                }
            }
        )

        let makeStateFromApiRequest = { (loadImpulse: Resource.LoadImpulse)
            -> Resource.StateProducerType in
            var request = makeApiRequest(loadImpulse)
                .map {
                    Resource.State.value(
                        valueBox: .init($0),
                        loadImpulse: loadImpulse,
                        fallbackError: nil
                    )
                }
                .flatMapError { error -> Resource.StateProducerType in
                    let errorState = Resource.State.error(
                        error: error,
                        loadImpulse: loadImpulse,
                        fallbackValueBox: nil
                    )
                    return SignalProducer(value: errorState)
                }

            request = request.prefix(
                value: .loading(
                    loadImpulse: loadImpulse,
                    fallbackValueBox: nil,
                    fallbackError: nil
                )
            )

            return request
        }

        var statesProducer = Resource.states(
            with: loadImpulseEmitter,
            load: makeStateFromApiRequest
        )

        if let cache = cache {
            statesProducer = statesProducer
                .persist(with: cache.persister)
                .combineWithCachedStates(from: cache.reader)
        }

        switch combinePreviousStateMode {
        case .none:
            break
        case let .combine(preferFallbackValueOverFallbackError):
            statesProducer = statesProducer.combinePrevious(
                preferFallbackValueOverFallbackError: preferFallbackValueOverFallbackError
            )
        }

        statesProducer = statesProducer.observe(on: UIScheduler())

        self.init(
            loadImpulseEmitter: loadImpulseEmitter,
            state: Property(initial: .notReady, then: statesProducer)
        )
    }
}

public typealias RefreshingEnded = Void

public enum CombinePreviousStateMode {
    case none
    case combine(preferFallbackValueOverFallbackError: Bool)
}
