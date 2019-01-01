import Foundation

open class URLSessionDatasource
<Value_: Codable, P_: Parameters, E_: DatasourceError>: DatasourceProtocol {

    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias ObservedValue = DatasourceState
    public typealias GenerateRequest = (LoadImpulse<P>) throws -> URLRequest
    public typealias GenerateError = (String) -> E
    private typealias InnerDatasource = ClosureDatasource<Value, P, E>

    public var loadImpulseEmitter: AnyLoadImpulseEmitter<P> {
        return innerDatasource.loadImpulseEmitter
    }

    public var currentValue: SynchronizedProperty<DatasourceState> {
        return innerDatasource.currentValue
    }

    private let innerDatasource: InnerDatasource
    private let generateRequest: GenerateRequest
    private let generateError: GenerateError
    private let stateGenerationDisposable = SynchronizedMutableProperty<Disposable?>(nil)

    public init(loadImpulseEmitter: AnyLoadImpulseEmitter<P>,
                generateError: @escaping GenerateError,
                generateRequest: @escaping GenerateRequest) {
        self.generateError = generateError
        self.generateRequest = generateRequest
        let generateState = URLSessionDatasource<Value, P, E>.generateState(generateError: generateError,
                                                                            generateRequest: generateRequest)
        self.innerDatasource = InnerDatasource(loadImpulseEmitter: loadImpulseEmitter, generateState)
    }

    public func observe(_ valuesOverTime: @escaping ValuesOverTime) -> Disposable {

        let disposable = innerDatasource.observe(valuesOverTime)
        return CompositeDisposable(disposable, objectToRetain: self)
    }

    public func removeObserver(with key: Int) {
        innerDatasource.removeObserver(with: key)
    }

    private static func generateState(generateError: @escaping GenerateError,
                                      generateRequest: @escaping GenerateRequest)
        -> InnerDatasource.GenerateState {

        return { loadImpulse, sendState -> Disposable in

            func sendError(_ error: E) {
                sendState(InnerDatasource.DatasourceState.error(
                    error: error,
                    loadImpulse: loadImpulse,
                    fallbackValueBox: nil
                ))
            }

            guard let urlRequest = try? generateRequest(loadImpulse) else {
                sendError(generateError("Request could not be generated"))
                return VoidDisposable()
            }

            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)

            let task = session.dataTask(with: urlRequest) { data, _, error in

                guard error == nil else {
                    sendError(generateError("""
                        Request could not be loaded -
                        we are too lazy to parse the actual error yet ;)
                        """))
                    return
                }

                // make sure we got data
                guard let responseData = data else {
                    sendError(generateError("responseData is nil"))
                    return
                }

                do {
                    let value = try JSONDecoder.decode(responseData,
                                                       to: Value.self)
                    let state = InnerDatasource.DatasourceState.value(valueBox: EquatableBox(value),
                                                                      loadImpulse: loadImpulse,
                                                                      fallbackError: nil)
                    sendState(state)
                } catch {
                    sendError(generateError("""
                        Value cannot be parsed: \(String(describing: error))
                        """))
                    return
                }
            }
            task.resume()

            return ActionDisposable { [weak task] in
                task?.cancel()
            }
        }
    }

}
