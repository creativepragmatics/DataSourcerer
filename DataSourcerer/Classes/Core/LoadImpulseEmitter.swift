import Foundation

public protocol LoadImpulseEmitterProtocol: TypedObservable where ObservedValue == LoadImpulse<P> {
    associatedtype P: Parameters
    typealias LoadImpulsesOverTime = ValuesOverTime

    func emit(_ loadImpulse: LoadImpulse<P>)
}

public extension LoadImpulseEmitterProtocol {
    var any: AnyLoadImpulseEmitter<P> {
        return AnyLoadImpulseEmitter(self)
    }
}

public struct AnyLoadImpulseEmitter<P_: Parameters>: LoadImpulseEmitterProtocol {
    public typealias P = P_

    private let _observe: (@escaping LoadImpulsesOverTime) -> Disposable
    private let _removeObserver: (Int) -> Void
    private let _emit: (LoadImpulse<P>) -> Void

    init<Emitter: LoadImpulseEmitterProtocol>(_ emitter: Emitter) where Emitter.P == P {
        self._emit = emitter.emit
        self._observe = emitter.observe
        self._removeObserver = emitter.removeObserver
    }

    public func emit(_ loadImpulse: LoadImpulse<P_>) {
        _emit(loadImpulse)
    }

    public func observe(_ loadImpulsesOverTime: @escaping LoadImpulsesOverTime) -> Disposable {
        return _observe(loadImpulsesOverTime)
    }

    public func removeObserver(with key: Int) {
        _removeObserver(key)
    }
}

public class DefaultLoadImpulseEmitter<P_: Parameters>: LoadImpulseEmitterProtocol, UntypedObservable {
    public typealias P = P_
    public typealias LI = LoadImpulse<P>

    private let impulseOnFirstObservation: LoadImpulse<P>?
    private let innerObservable = DefaultObservable<LI>()
    private var isObserved = SynchronizedMutableProperty(false)

    public init(emitOnFirstObservation impulseOnFirstObservation: LoadImpulse<P>?) {
        self.impulseOnFirstObservation = impulseOnFirstObservation
    }

    public func observe(_ observe: @escaping LoadImpulsesOverTime) -> Disposable {

        defer {
            let isFirstObservation = isObserved.set(true, ifCurrentValueIs: false)
            if isFirstObservation, let impulseOnFirstObservation = self.impulseOnFirstObservation {
                emit(impulseOnFirstObservation)
            }
        }

        let innerDisposable = innerObservable.observe(observe)
        let selfDisposable: Disposable = InstanceRetainingDisposable(self)
        return CompositeDisposable([innerDisposable, selfDisposable])
    }

    public func emit(_ loadImpulse: LoadImpulse<P>) {
        innerObservable.emit(loadImpulse)
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

}

public class RecurringLoadImpulseEmitter<P_: Parameters>: LoadImpulseEmitterProtocol, UntypedObservable {
    public typealias P = P_
    public typealias LI = LoadImpulse<P>

    private let lastLoadImpulse: LoadImpulse<P>?
    private let innerEmitter: DefaultLoadImpulseEmitter<P>
    private let disposeBag = DisposeBag()
    private var timer = SynchronizedMutableProperty<DispatchSourceTimer?>(nil)
    private var isObserved = SynchronizedMutableProperty(false)
    private let timerExecuter = SynchronizedExecuter()
    private let timerEmitQueue: DispatchQueue
    public var timerMode: TimerMode {
        didSet {
            if let lastLoadImpulse = lastLoadImpulse {
                emit(lastLoadImpulse)
            }
            resetTimer()
        }
    }

    public init(emitOnFirstObservation impulseOnFirstObservation: LoadImpulse<P>?,
                timerMode: TimerMode = .none,
                timerEmitQueue: DispatchQueue? = nil) {

        self.lastLoadImpulse = impulseOnFirstObservation
        self.timerMode = timerMode
        self.innerEmitter = DefaultLoadImpulseEmitter<P>(emitOnFirstObservation: impulseOnFirstObservation)
        self.timerEmitQueue = timerEmitQueue ??
            DispatchQueue(label: "datasourcerer.recurringloadimpulseemitter.timer", attributes: [])
    }

    private func resetTimer() {

        timer.modify { [weak self] timer in
            timer?.cancel()
            guard let self = self else { return }

            switch self.timerMode {
            case .none:
                break
            case let .timeInterval(timeInterval):
                let newTimer = DispatchSource.makeTimerSource(queue: self.timerEmitQueue)
                newTimer.schedule(deadline: .now(), repeating: timeInterval, leeway: .milliseconds(100))
                newTimer.setEventHandler { [weak self] in
                    guard let lastLoadImpulse = self?.lastLoadImpulse else { return }
                    self?.emit(lastLoadImpulse)
                }
                newTimer.resume()
                timer = newTimer
            }
        }
    }

    public func observe(_ observe: @escaping LoadImpulsesOverTime) -> Disposable {

        defer {
            let isFirstObservation = isObserved.set(true, ifCurrentValueIs: false)
            if isFirstObservation {
                innerEmitter.observe { [weak self] loadImpulse in
                    self?.emit(loadImpulse)
                    self?.resetTimer()
                }.disposed(by: disposeBag)
            }
        }

        let innerDisposable = innerEmitter.observe(observe)
        return CompositeDisposable(innerDisposable, objectToRetain: self)
    }

    public func emit(_ loadImpulse: LoadImpulse<P>) {
        innerEmitter.emit(loadImpulse)
    }

    public func removeObserver(with key: Int) {
        innerEmitter.removeObserver(with: key)
    }

    deinit {
        disposeBag.dispose()
    }

    public enum TimerMode {
        case none
        case timeInterval(DispatchTimeInterval)
    }

}
