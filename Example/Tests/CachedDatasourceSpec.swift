@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class CachedDatasourceSpec: QuickSpec {

    private let testStringLoadImpulse = LoadImpulse(params: "1", type: .initial)

    private lazy var testStringState: ResourceState<String, String, TestStateError> = {
        return ResourceState(
            provisioningState: .result,
            loadImpulse: testStringLoadImpulse,
            value: EquatableBox("1"),
            error: nil
        )
    }()

    private func loadImpulseEmitter() -> AnyLoadImpulseEmitter<String> {
        return SimpleLoadImpulseEmitter(initialImpulse: self.testStringLoadImpulse).any
    }

    override func spec() {
        describe("Datasource.persistedCachedState") {
//            it("sends states to an observer") {
//
//                let loadImpulseEmitter = self.loadImpulseEmitter()
//                let persister = TestResourceStatePersister<String, String, TestStateError>()
//                persister.persist(OneTwoThreeStringTestStates.oneTwoThreeStringStates[0])
//
//                let datasource = Datasource(
//                    testStates: OneTwoThreeStringTestStates.oneTwoThreeStringStates,
//                    testError: TestStateError.unknown(description: "Value unavailable"),
//                    loadImpulseEmitter: loadImpulseEmitter
//                    )
//                    .persistedCachedState(persister: persister.any,
//                                          loadImpulseEmitter: loadImpulseEmitter,
//                                          cacheLoadError: TestStateError.cacheCouldNotLoad(.default))
//
//
//                var observedStates: [State<String, String, TestStateError>] = []
//
//                let disposable = datasource.observe({ state in
//                    observedStates.append(state)
//                })
//
//                OneTwoThreeStringTestStates.oneTwoThreeStringStates.forEach({ state in
//                    guard let loadImpulse = state.loadImpulse,
//                        loadImpulse.parameters != self.testStringLoadImpulse.parameters else {
//                        return
//                    }
//                    loadImpulseEmitter.emit(loadImpulse)
//                })
//
//                disposable.dispose()
//
//                expect(observedStates).to(contain(OneTwoThreeStringTestStates.oneTwoThreeStringStates))
//            }
            it("should release observer after disposal") {

                let loadImpulseEmitter = self.loadImpulseEmitter()
                let persister = TestResourceStatePersister<String, String, TestStateError>()
                persister.persist(OneTwoThreeStringTestStates.oneTwoThreeStringStates[0])

                let datasource = ValueStream(
                    testStates: OneTwoThreeStringTestStates.oneTwoThreeStringStates,
                    testError: TestStateError.unknown(description: "Value unavailable"),
                    loadImpulseEmitter: loadImpulseEmitter
                    )
                    .persistedCachedState(persister: persister.any,
                                          loadImpulseEmitter: loadImpulseEmitter,
                                          cacheLoadError: TestStateError.cacheCouldNotLoad(.default))
                    .skipRepeats()

                weak var testStr: NSMutableString?

                let testScope: () -> Disposable = {
                    let innerStr = NSMutableString(string: "")

                    let disposable = datasource.observe({ state in
                        if let value = state.value?.value {
                            innerStr.append(value)
                        }
                    })

                    testStr = innerStr
                    return disposable
                }

                let disposable = testScope()
                expect(testStr) == "1"

                loadImpulseEmitter.emit(loadImpulse: LoadImpulse(params: "2", type: LoadImpulseType(mode: .fullRefresh, issuer: .user)), on: .current)
                expect(testStr) == "12"

                disposable.dispose()

                // Force synchronous access to disposable observers so assert works synchronously.
                // Alternatively, a wait or waitUntil assert could be used, but this is
                // less complex.
                expect(disposable.isDisposed) == true

                expect(testStr).to(beNil())
            }
//            it("should release all resources on disposal") {
//
//                weak var testStr: NSMutableString?
//
//                struct Resources {
//                    let disposable: Disposable
//                    let loadImpulseEmitter: WeakReference<SimpleLoadImpulseEmitter<String>>
//                    let primaryDatasource: WeakReference<Datasource<State<String, String, TestStateError>>>
//                    let cacheDatasource: WeakReference<Datasource<String, String, TestStateError>>
//                    let cachedDatasource: WeakReference<Datasource<String, String, TestStateError>>
//
//                    var isReleased: Bool {
//                        return disposable.isDisposed && loadImpulseEmitter.isNil && primaryDatasource.isNil &&
//                            cacheDatasource.isNil && cachedDatasource.isNil
//                    }
//                }
//
//                let testScope: () -> Resources = {
//                    let loadImpulseEmitter = self.loadImpulseEmitter()
//                    let primaryDatasource = OneTwoThreeStringTestDatasource(loadImpulseEmitter: loadImpulseEmitter.any)
//                    let cacheDatasource = self.cacheDatasource(persistedState: self.testStringState,
//                                                               loadImpulseEmitter: primaryDatasource.loadImpulseEmitter)
//                    let datasource = primaryDatasource.cache(with: cacheDatasource.any,
//                                                             loadImpulseEmitter: loadImpulseEmitter.any,
//                                                             persister: cacheDatasource.persister)
//
//                    let innerStr = NSMutableString(string: "")
//                    testStr = innerStr
//
//                    let disposable = datasource.observe({ state in
//                        if let value = state.value?.value {
//                            innerStr.append(value)
//                        }
//                    })
//
//                    return Resources(
//                        disposable: disposable,
//                        loadImpulseEmitter: WeakReference(loadImpulseEmitter),
//                        primaryDatasource: WeakReference(primaryDatasource),
//                        cacheDatasource: WeakReference(cacheDatasource),
//                        cachedDatasource: WeakReference(datasource)
//                    )
//                }
//
//                let resources = testScope()
//
//                expect(resources.isReleased) == false
//
//                expect(testStr) == "1"
//
//                resources.disposable.dispose()
//
//                // Force synchronous access to disposable observers so assert works synchronously.
//                // Alternatively, a wait or waitUntil assert could be used, but this is
//                // less complex.
//                expect(resources.disposable.isDisposed) == true
//
//                expect(resources.isReleased) == true
//                expect(testStr).to(beNil())
//            }
        }
    }

}
