import Foundation

/// Thread-safe executions by employing dispatch queues.
///
/// - Read more here: http://www.fieryrobot.com/blog/2010/09/01/synchronization-using-grand-central-dispatch/
public struct SynchronizedExecuter {

    public let queue: DispatchQueue
    public let dispatchSpecificKey = DispatchSpecificKey<UInt8>()
    public let dispatchSpecificValue = UInt8.max

    public init(queue: DispatchQueue? = nil, label: String = "DataSourcerer-SynchronizedExecuter") {
        if let queue = queue {
            self.queue = queue
        } else {
            self.queue = DispatchQueue(label: label)
        }
        self.queue.setSpecific(key: dispatchSpecificKey, value: dispatchSpecificValue)
    }

    public func async(_ execute: @escaping () -> Void) {
        queue.async(execute: execute)
    }

    public func sync(_ execute: () -> Void) {
        if DispatchQueue.getSpecific(key: dispatchSpecificKey) == dispatchSpecificValue {
            execute()
        } else {
            queue.sync(execute: execute)
        }
    }

}
