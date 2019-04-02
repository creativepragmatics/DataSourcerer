import Foundation

/// Provides the data for a sectioned or unsectioned list. Can be reused
/// by multiple views displaying its data.
public struct Datasource<Value, P: ResourceParams, E: ResourceError> {
    public typealias ObservedState = ResourceState<Value, P, E>
    public typealias ErrorString = String

    public let state: ShareableValueStream<ObservedState>
    public let loadImpulseEmitter: AnyLoadImpulseEmitter<P>

    public init(_ state: ShareableValueStream<ObservedState>,
                loadImpulseEmitter: AnyLoadImpulseEmitter<P>) {
        self.state = state
        self.loadImpulseEmitter = loadImpulseEmitter
    }
}

public extension Datasource {

    func refresh(
        params: P,
        type: LoadImpulseType,
        on queue: LoadImpulseEmitterQueue = .distinct(DispatchQueue(label: "PublicReposViewModel.refresh"))
    ) {
        let loadImpulse = LoadImpulse(params: params, type: type)
        loadImpulseEmitter.emit(loadImpulse: loadImpulse, on: queue)
    }
}

public extension Datasource {

    init<S: Sequence>(
        combine datasources: S,
        map: @escaping ([ObservedState]) -> ObservedState
    ) where S.Element == Datasource<Value, P, E> {

        let observables = datasources
            .map { $0.state.any }

        state = AnyObservable
            .combine(observables: observables, map: map)
            .shareable(initialValue: .notReady)

        // Insert nonfunctional load impulse emitter - values will only flow from the
        // sub datasources.
        self.loadImpulseEmitter = SimpleLoadImpulseEmitter(initialImpulse: nil).any
    }

    init(
        combine first: Datasource<Value, P, E>,
        with second: Datasource<Value, P, E>,
        map: @escaping (ObservedState, ObservedState) -> ObservedState
        ) {

        self.init(combine: [first, second]) { states
            -> ResourceState<Value, P, E> in
            map(states[0], states[1])
        }
    }

    init(
        combine first: Datasource<Value, P, E>,
        with second: Datasource<Value, P, E>,
        and third: Datasource<Value, P, E>,
        map: @escaping (ObservedState, ObservedState, ObservedState) -> ObservedState
        ) {

        self.init(combine: [first, second, third]) { states
            -> ResourceState<Value, P, E> in
            map(states[0], states[1], states[2])
        }
    }

}

public extension Datasource where P == NoResourceParams {

    func refresh(
        type: LoadImpulseType,
        on queue: LoadImpulseEmitterQueue = .distinct(DispatchQueue(label: "PublicReposViewModel.refresh"))
        ) {
        refresh(params: NoResourceParams(), type: type, on: queue)
    }
}

public extension Datasource {

    enum CacheBehavior {
        case none
        case persist(persister: AnyResourceStatePersister<Value, P, E>, cacheLoadError: E)

        public func apply(on observable: AnyObservable<ResourceState<Value, P, E>>,
                          loadImpulseEmitter: AnyLoadImpulseEmitter<P>)
            -> AnyObservable<ResourceState<Value, P, E>> {
                switch self {
                case .none:
                    return observable
                case let .persist(persister, cacheLoadError):
                    return observable.persistedCachedState(
                        persister: persister,
                        loadImpulseEmitter: loadImpulseEmitter,
                        cacheLoadError: cacheLoadError
                    )
                }
        }
    }
}

public extension Datasource {

    enum LoadImpulseBehavior {
        case `default`(initialParameters: P?)
        case recurring(
            initialParameters: P?,
            timerMode: RecurringLoadImpulseEmitter<P>.TimerMode,
            timerEmitQueue: DispatchQueue?
        )
        case instance(AnyLoadImpulseEmitter<P>)

        var loadImpulseEmitter: AnyLoadImpulseEmitter<P> {
            switch self {
            case let .default(initialParameters):
                let initialImpulse = initialParameters.map { LoadImpulse<P>(params: $0, type: .initial) }
                return SimpleLoadImpulseEmitter(initialImpulse: initialImpulse).any
            case let .instance(loadImpulseEmitter):
                return loadImpulseEmitter
            case let .recurring(initialParameters,
                                timerMode,
                                timerEmitQueue):
                let initialImpulse = initialParameters.map { LoadImpulse<P>(params: $0, type: .initial) }
                return RecurringLoadImpulseEmitter(initialImpulse: initialImpulse,
                                                   timerMode: timerMode,
                                                   timerEmitQueue: timerEmitQueue).any
            }
        }
    }

}

//public extension Datasource where Value: Codable {
//
//    init(
//        urlRequest: @escaping (LoadImpulse<P>) throws -> URLRequest,
//        mapErrorString: @escaping (ErrorString) -> E,
//        cacheBehavior: CacheBehavior,
//        loadImpulseBehavior: LoadImpulseBehavior
//        ) {
//
//        let loadImpulseEmitter = loadImpulseBehavior.loadImpulseEmitter
//
//        let states = ValueStream<ObservedState>(
//            loadStatesWithURLRequest: urlRequest,
//            mapErrorString: mapErrorString,
//            loadImpulseEmitter: loadImpulseEmitter
//            )
//            .retainLastResultState()
//
//        let cachedStates = cacheBehavior
//            .apply(on: states.any,
//                   loadImpulseEmitter: loadImpulseEmitter)
//            .skipRepeats()
//            .observeOnUIThread()
//
//        let shareableCachedStates = cachedStates
//            .shareable(initialValue: ResourceState<Value, P, E>.notReady)
//
//        self.init(shareableCachedStates, loadImpulseEmitter: loadImpulseEmitter)
//    }
//}
