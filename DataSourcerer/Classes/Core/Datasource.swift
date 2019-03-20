import Foundation

/// Provides the data for a sectioned or unsectioned list. Can be reused
/// by multiple views displaying its data.
public struct Datasource<Value, P: ResourceParams, E: ResourceError> {
    public typealias ObservedState = ResourceState<Value, P, E>

    public let state: ShareableValueStream<ObservedState>
    public let loadImpulseEmitter: AnyLoadImpulseEmitter<P>

    public init(_ state: ShareableValueStream<ObservedState>,
                loadImpulseEmitter: AnyLoadImpulseEmitter<P>) {
        self.state = state
        self.loadImpulseEmitter = loadImpulseEmitter
    }
}

public extension Datasource {

    enum CacheBehavior<Value, P: ResourceParams, E: ResourceError> {
        case none
        case persist(persister: AnyResourceStatePersister<Value, P, E>, cacheLoadError: E)

        func apply(on observable: AnyObservable<ResourceState<Value, P, E>>,
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

    enum LoadImpulseBehavior<P: ResourceParams> {
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
                let initialImpulse = initialParameters.map { LoadImpulse<P>(parameters: $0) }
                return SimpleLoadImpulseEmitter(initialImpulse: initialImpulse).any
            case let .instance(loadImpulseEmitter):
                return loadImpulseEmitter
            case let .recurring(initialParameters,
                                timerMode,
                                timerEmitQueue):
                let initialImpulse = initialParameters.map { LoadImpulse<P>(parameters: $0) }
                return RecurringLoadImpulseEmitter(initialImpulse: initialImpulse,
                                                   timerMode: timerMode,
                                                   timerEmitQueue: timerEmitQueue).any
            }
        }
    }

}

public extension Datasource where Value: Codable {

    typealias ErrorString = String

    init(
        urlRequest: @escaping (LoadImpulse<P>) throws -> URLRequest,
        mapErrorString: @escaping (ErrorString) -> E,
        cacheBehavior: CacheBehavior<Value, P, E>,
        loadImpulseBehavior: LoadImpulseBehavior<P>
        ) {

        let loadImpulseEmitter = loadImpulseBehavior.loadImpulseEmitter

        let states = ValueStream<ObservedState>(
            loadStatesWithURLRequest: urlRequest,
            mapErrorString: mapErrorString,
            loadImpulseEmitter: loadImpulseEmitter
            )
            .retainLastResultState()

        let cachedStates = cacheBehavior
            .apply(on: states.any,
                   loadImpulseEmitter: loadImpulseEmitter)
            .skipRepeats()
            .observeOnUIThread()

        let shareableCachedStates = cachedStates
            .shareable(initialValue: ResourceState<Value, P, E>.notReady)

        self.init(shareableCachedStates, loadImpulseEmitter: loadImpulseEmitter)
    }
}
