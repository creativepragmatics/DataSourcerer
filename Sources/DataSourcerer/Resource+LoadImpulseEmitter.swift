import Foundation
import ReactiveSwift

public extension Resource {

    struct LoadImpulseEmitter {
        public let loadImpulses: SignalProducer<LoadImpulse, Never>
        public let emit: (LoadImpulse, EmitTime) -> Void

        public enum EmitTime {
            case now
            case nowAsync(DispatchQueue)
        }
    }
}

public extension Resource.LoadImpulseEmitter {

    init(imperativeWithInitialImpulse initialImpulse: Resource.LoadImpulse?) {
        let pipe = Signal<Resource.LoadImpulse, Never>.pipe()

        loadImpulses = {
            var impulses = SignalProducer(pipe.output)
            if let initialImpulse = initialImpulse {
                impulses = impulses.prefix(value: initialImpulse)
            }
            return impulses
        }()

        emit = { impulse, time in
            let send = { pipe.input.send(value: impulse) }

            switch time {
            case .now:
                send()
            case let .nowAsync(queue):
                queue.async(execute: send)
            }
        }
    }
}
