import Foundation

public protocol Disposable: AnyObject {
    func dispose()

    var isDisposed: Bool { get }
}

public extension Disposable {
    func disposed(by bag: DisposeBag) {
        bag.add(self)
    }
}

public final class InstanceRetainingDisposable: Disposable {

    private var instance: AnyObject?
    private var _isDisposed: Bool = false
    public var isDisposed: Bool {
        return _isDisposed
    }

    init(_ instance: AnyObject) {
        self.instance = instance
    }

    public func dispose() {
        instance = nil // remove retain on instance
        _isDisposed = true
    }

}

public class CompositeDisposable: Disposable {

    private let disposables = SynchronizedMutableProperty<[Disposable]>([])

    public var isDisposed: Bool {
        if disposables.value.contains(where: { $0.isDisposed == false }) {
            return false
        } else {
            return true
        }
    }

    init() {}

    init(_ disposables: [Disposable]) {
        self.disposables.value = disposables
    }

    public func add(_ disposable: Disposable) {
        disposables.modify({ $0 += [disposable] })
    }

    public func dispose() {
        disposables.value
            .filter({ $0.isDisposed == false })
            .forEach({ $0.dispose() })
        disposables.value = []
    }

}

public final class VoidDisposable: Disposable {

    private var _isDisposed: Bool = false
    public var isDisposed: Bool {
        return _isDisposed
    }

    public init() {}
    public func dispose() {
        _isDisposed = true
    }

}

public extension CompositeDisposable {

    convenience init(_ disposableA: Disposable, objectToRetain: AnyObject) {
        self.init([disposableA, InstanceRetainingDisposable(objectToRetain)])
    }
}

public final class ObserverDisposable: Disposable {

    var key: Int
    var observable: UntypedObservable?
    private var _isDisposed: Bool = false
    public var isDisposed: Bool {
        return _isDisposed
    }

    public init(observable: UntypedObservable, key: Int) {
        self.observable = observable
        self.key = key
    }

    public func dispose() {
        self.observable?.removeObserver(with: key)
        self.observable = nil // remove retain on instance
        _isDisposed = true
    }
}

public class DisposeBag: CompositeDisposable {

    public override init() {
        super.init()
    }

    deinit {
        dispose()
    }
}
