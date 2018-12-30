import Foundation

open class DatasourceEndedLoading<Datasource: DatasourceProtocol>: TypedObservable {
    public typealias ObservedValue = Void
    public typealias EndedLoadingEventsOverTime = (()) -> Void

    private let datasource: Datasource
    private let disposeBag = DisposeBag()
    private var isLoading = SynchronizedMutableProperty<Bool>(false)
    private var isObserved = SynchronizedMutableProperty<Bool>(false)
    private let innerObservable = DefaultStatefulObservable<Void>(())

    init(datasource: Datasource) {
        self.datasource = datasource
    }

    private func startObserving() {

        datasource.loadImpulseEmitter
            .observe { [weak self] _ in
                self?.isLoading.value = true
            }
            .disposed(by: disposeBag)

        datasource
            .observe { [weak self] state in
                guard let self = self,
                    self.isLoading.value == false,
                    state.loadImpulse?.parameters != nil else { return }

                switch state.provisioningState {
                case .result:
                    self.isLoading.value = false
                    self.innerObservable.emit(())
                case .notReady, .loading:
                    break
                }
            }
            .disposed(by: disposeBag)
    }

    public func observe(_ valuesOverTime: @escaping EndedLoadingEventsOverTime) -> Disposable {

        defer {
            let isFirstObservation = isObserved.set(true, ifCurrentValueIs: false)
            if isFirstObservation {
                startObserving()
            }
        }

        let innerDisposable = innerObservable.observe(valuesOverTime)
        return CompositeDisposable(innerDisposable, objectToRetain: self)
    }

    public func removeObserver(with key: Int) {
        innerObservable.removeObserver(with: key)
    }

}

public extension DatasourceProtocol {

    func observeEndedLoading(_ endedLoadingEventsOverTime:
        @escaping DatasourceEndedLoading<Self>.EndedLoadingEventsOverTime) -> Disposable {
        return DatasourceEndedLoading(datasource: self)
            .observe(endedLoadingEventsOverTime)
    }
}
