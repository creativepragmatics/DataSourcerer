import Foundation

public protocol Observable {
    func removeObserver(with: Int)
}

public protocol Disposable: class {
    func dispose()
}

extension Disposable {
    func disposed(by bag: DisposeBag) {
        bag.add(self)
    }
}

public final class InstanceRetainingDisposable: Disposable {
    
    private var instance: AnyObject?
    
    init(_ instance: AnyObject) {
        self.instance = instance
    }
    
    public func dispose() {
        instance = nil // remove retain on instance
    }
    
}


public final class CompositeDisposable: Disposable {
    
    private var disposables: [Disposable]
    
    init(_ disposables: [Disposable]) {
        self.disposables = disposables
    }
    
    public func dispose() {
        disposables.forEach({ $0.dispose() })
        disposables = [] // remove retain on disposables
    }
    
}

public final class ObserverDisposable: Disposable {
    
    var key: Int
    var observable: Observable?
    
    public init(observable: Observable, key: Int) {
        self.observable = observable
        self.key = key
    }
    
    public func dispose() {
        self.observable?.removeObserver(with: key)
        self.observable = nil // remove retain on instance
    }
}

public final class DisposeBag {
    
    var disposables: SynchronizedProperty<[Disposable]>
    
    init() {
        self.disposables = SynchronizedProperty([])
    }
    
    public func add(_ disposable: Disposable) {
        disposables.modify({ $0 += [disposable] })
    }
    
    public func dispose() {
        disposables.value.forEach { $0.dispose() }
    }
    
    deinit {
        dispose()
    }
}

open class DefaultObservable<T>: Observable {
    
    public typealias ValuesOverTime = (T) -> ()
    
    private var observers = SynchronizedProperty([Int: ValuesOverTime]())
    
    open func observe(_ observe: @escaping ValuesOverTime) -> Disposable {
        
        let uniqueKey = Int(arc4random_uniform(10000))
        observers.modify({ $0[uniqueKey] = observe })
        return ObserverDisposable(observable: self, key: uniqueKey)
    }
    
    open func emit(_ value: T) {
        
        observers.value.values.forEach({ $0(value) })
    }
    
    open func removeObserver(with key: Int) {
        
        observers.modify({ $0.removeValue(forKey: key) })
    }
}
