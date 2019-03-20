import Foundation

public protocol LoadImpulseEmitterProtocol: ObservableProtocol where ObservedValue == LoadImpulse<P> {
    associatedtype P: ResourceParams
    typealias LoadImpulsesOverTime = ValuesOverTime

    func emit(_ loadImpulse: LoadImpulse<P>)
}

public extension LoadImpulseEmitterProtocol {
    var any: AnyLoadImpulseEmitter<P> {
        return AnyLoadImpulseEmitter(self)
    }
}

public struct AnyLoadImpulseEmitter<P_: ResourceParams>: LoadImpulseEmitterProtocol {
    public typealias P = P_

    private let _observe: (@escaping LoadImpulsesOverTime) -> Disposable
    private let _emit: (LoadImpulse<P>) -> Void

    init<Emitter: LoadImpulseEmitterProtocol>(_ emitter: Emitter) where Emitter.P == P {
        self._emit = emitter.emit
        self._observe = emitter.observe
    }

    public func emit(_ loadImpulse: LoadImpulse<P_>) {
        _emit(loadImpulse)
    }

    public func observe(_ loadImpulsesOverTime: @escaping LoadImpulsesOverTime) -> Disposable {
        return _observe(loadImpulsesOverTime)
    }
}

public class SimpleLoadImpulseEmitter<P_: ResourceParams>: LoadImpulseEmitterProtocol, ObservableProtocol {
    public typealias P = P_
    public typealias LI = LoadImpulse<P>

    private let initialImpulse: LoadImpulse<P>?
    private let broadcastObservable = BroadcastObservable<LI>()

    public init(initialImpulse: LoadImpulse<P>?) {
        self.initialImpulse = initialImpulse
    }

    public func observe(_ observe: @escaping LoadImpulsesOverTime) -> Disposable {

        if let initialImpulse = initialImpulse {
            observe(initialImpulse)
        }

        return broadcastObservable.observe(observe)
    }

    public func emit(_ loadImpulse: LoadImpulse<P>) {
        broadcastObservable.emit(loadImpulse)
    }

}

public class RecurringLoadImpulseEmitter<P_: ResourceParams>: LoadImpulseEmitterProtocol, ObservableProtocol {
    public typealias P = P_
    public typealias LI = LoadImpulse<P>

    private let lastLoadImpulse: LoadImpulse<P>?
    private let innerEmitter: SimpleLoadImpulseEmitter<P>
    private let disposeBag = DisposeBag()
    private var timer = SynchronizedMutableProperty<DispatchSourceTimer?>(nil)
    private var isObserved = SynchronizedMutableProperty(false)
    private let timerExecuter = SynchronizedExecuter()
    private let timerEmitQueue: DispatchQueue

    // TODO: refactor to use SynchronizedMutableProperty
    public var timerMode: TimerMode {
        didSet {
            resetTimer()
        }
    }

    public init(initialImpulse: LoadImpulse<P>?,
                timerMode: TimerMode = .none,
                timerEmitQueue: DispatchQueue? = nil) {

        self.lastLoadImpulse = initialImpulse
        self.timerMode = timerMode
        self.innerEmitter = SimpleLoadImpulseEmitter<P>(initialImpulse: initialImpulse)
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
                newTimer.schedule(deadline: .now() + timeInterval,
                                  repeating: timeInterval,
                                  leeway: .milliseconds(100))
                newTimer.setEventHandler { [weak self] in
                    guard let lastLoadImpulse = self?.lastLoadImpulse else { return }
                    self?.innerEmitter.emit(lastLoadImpulse)
                }
                newTimer.resume()
                timer = newTimer
            }
        }
    }

    public func observe(_ observe: @escaping LoadImpulsesOverTime) -> Disposable {

        defer {
            if isObserved.set(true, ifCurrentValueIs: false) {
                resetTimer()
            }
        }

        let innerDisposable = innerEmitter.observe(observe)
        return CompositeDisposable(innerDisposable, objectToRetain: self)
    }

    public func emit(_ loadImpulse: LoadImpulse<P>) {
        innerEmitter.emit(loadImpulse)
        resetTimer()
    }

    deinit {
        disposeBag.dispose()
    }

    public enum TimerMode {
        case none
        case timeInterval(DispatchTimeInterval)
    }

}
