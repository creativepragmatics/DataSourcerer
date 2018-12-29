import Foundation

open class Datasource
<Value_, P_: Parameters, E_: DatasourceError>: DatasourceProtocol {
    public typealias Value = Value_
    public typealias P = P_
    public typealias E = E_
    public typealias ObservedValue = DatasourceState
    public typealias GenerateState = (LoadImpulse<P>, SendState) -> Disposable
    public typealias SendState = (State<Value, P, E>) -> ()

    public let sendsFirstStateSynchronously = true
    public let loadImpulseEmitter: AnyLoadImpulseEmitter<P>
    public var lastValue: SynchronizedProperty<DatasourceState?> {
        return innerObservable.lastValue
    }

    private let generateState: GenerateState
    private let isObserved = SynchronizedMutableProperty(false)
    private let disposeBag = DisposeBag()
    private let stateGenerationDisposable = SynchronizedMutableProperty<Disposable?>(nil)

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

    private let innerObservable = InnerStateObservable<Value, P, E>()

    public init(loadImpulseEmitter: AnyLoadImpulseEmitter<P>, _ generateState: @escaping GenerateState) {
        self.loadImpulseEmitter = loadImpulseEmitter
        self.generateState = generateState
    }

    public func observe(_ statesOverTime: @escaping ValuesOverTime) -> Disposable {

        defer {
            let isFirstObservation = isObserved.set(true, ifCurrentValueIs: false)
            if isFirstObservation {
                startObserving()
            }
        }

        // Send .notReady right now, because sendsFirstStateSynchronously == true
        statesOverTime(DatasourceState.notReady)

        let innerDisposable = innerObservable.observe(statesOverTime)
        return CompositeDisposable(innerDisposable, objectToRetain: self)
    }

    private func startObserving() {
        loadImpulseEmitter.observe { [weak self] loadImpulse in
            guard let strongSelf = self else { return }

            strongSelf.stateGenerationDisposable.value?.dispose()
            let disposable = strongSelf
                .generateState(loadImpulse, { [weak self] nextState in
                    guard let strongSelf = self else { return }
                    strongSelf.innerObservable.emit(nextState)
                })
            strongSelf.stateGenerationDisposable.value = disposable
            disposable.disposed(by: strongSelf.disposeBag)
        }.disposed(by: disposeBag)
    }

}


