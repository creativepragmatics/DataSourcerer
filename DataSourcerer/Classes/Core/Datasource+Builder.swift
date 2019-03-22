import Foundation

public extension Datasource {

    struct Builder {

        public struct ResourceStateAndLoadImpulseEmitterSelected {
            let resourceState: AnyObservable<ResourceState<Value, P, E>>
            let loadImpulseEmitter: AnyLoadImpulseEmitter<P>

            public func cacheBehavior(_ cacheBehavior: CacheBehavior) -> CacheBehaviorSelected {
                return CacheBehaviorSelected(previous: self,
                                             cacheBehavior: cacheBehavior)
            }
        }

        public struct CacheBehaviorSelected {
            let previous: ResourceStateAndLoadImpulseEmitterSelected
            let cacheBehavior: CacheBehavior

            public var datasource: Datasource {

                let cachedStates = cacheBehavior
                    .apply(on: previous.resourceState,
                           loadImpulseEmitter: previous.loadImpulseEmitter)
                    .skipRepeats()
                    .observeOnUIThread()

                let shareableCachedState = cachedStates
                    .shareable(initialValue: ResourceState<Value, P, E>.notReady)

                return Datasource<Value, P, E>(
                    shareableCachedState,
                    loadImpulseEmitter: previous.loadImpulseEmitter
                )
            }

        }

        public struct ValueStreamSelected {
            let states: ValueStream<ObservedState>
        }
    }

}

public extension Datasource.Builder where Value: Codable {

    struct LoadFromURLRequestSelected {
        let urlRequest: (LoadImpulse<P>) throws -> URLRequest

        public func mapErrorToString(_ mapErrorString: @escaping (Datasource.ErrorString) -> E)
            -> LoadFromURLErrorMappingSelected {
                return LoadFromURLErrorMappingSelected(
                    urlRequestSelected: self,
                    mapErrorString: mapErrorString
                )
        }
    }

    struct LoadFromURLErrorMappingSelected {
        let urlRequestSelected: LoadFromURLRequestSelected
        let mapErrorString: (Datasource.ErrorString) -> E

        public func loadImpulseBehavior(_ loadImpulseBehavior: Datasource.LoadImpulseBehavior)
            -> ResourceStateAndLoadImpulseEmitterSelected {

                let resourceState = ValueStream<Datasource.ObservedState>(
                    loadStatesWithURLRequest: urlRequestSelected.urlRequest,
                    mapErrorString: mapErrorString,
                    loadImpulseEmitter: loadImpulseBehavior.loadImpulseEmitter
                    )
                    .rememberLatestSuccessAndError()

                return ResourceStateAndLoadImpulseEmitterSelected(
                    resourceState: resourceState,
                    loadImpulseEmitter: loadImpulseBehavior.loadImpulseEmitter
                )
        }

    }
}

public extension Datasource where Value: Codable {

    static func loadFromURL(
        urlRequest: @escaping (LoadImpulse<P>) throws -> URLRequest,
        withParameterType: P.Type,
        expectResponseValueType: Value.Type,
        failWithError: E.Type
        ) -> Builder.LoadFromURLRequestSelected {
        return Builder.LoadFromURLRequestSelected(urlRequest: urlRequest)
    }
}
