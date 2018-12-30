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

    public var isDisposed: Bool {
        return _isDisposed.value
    }

    private var instance: AnyObject?
    private let _isDisposed = SynchronizedMutableProperty(false)

    init(_ instance: AnyObject) {
        self.instance = instance
    }

    public func dispose() {
        instance = nil // remove retain on instance
        _isDisposed.value = true
    }

}

public final class CompositeDisposable: Disposable {

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
        disposables.value.forEach({ $0.dispose() })
        disposables.value = []
    }

}

public final class VoidDisposable: Disposable {

    public var isDisposed: Bool {
        return _isDisposed.value
    }

    private let _isDisposed = SynchronizedMutableProperty(false)

    public init() {}
    public func dispose() {
        _isDisposed.value = true
    }

}

public extension CompositeDisposable {

    convenience init(_ disposableA: Disposable, objectToRetain: AnyObject) {
        self.init([disposableA, InstanceRetainingDisposable(objectToRetain)])
    }
}

public final class ActionDisposable: Disposable {

    public var isDisposed: Bool {
        return _isDisposed.value
    }

    private var action: (() -> Void)?
    private let _isDisposed = SynchronizedMutableProperty(false)

    public init(_ action: @escaping () -> Void) {
        self.action = action
    }

    public func dispose() {
        guard !isDisposed else { return }

        action?()
        // Release just in case the instance is kept alive:
        action = nil
        _isDisposed.value = true
    }
}

public final class DisposeBag {

    private let disposable = CompositeDisposable()

    public init() {}

    public func add(_ disposable: Disposable) {
        self.disposable.add(disposable)
    }

    public func dispose() {
        disposable.dispose()
    }

    deinit {
        dispose()
    }
}
