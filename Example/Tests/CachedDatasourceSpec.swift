@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class CachedDatasourceSpec: QuickSpec {

    private let testStringLoadImpulse =
        LoadImpulse(parameters: OneTwoThreeStringTestDatasource.initialRequestParameter)

    private lazy var testStringState: State<String, String, TestDatasourceError> = {
        return State(
            provisioningState: .result,
            loadImpulse: testStringLoadImpulse,
            value: EquatableBox("1"),
            error: nil
        )
    }()

    private func loadImpulseEmitter() -> DefaultLoadImpulseEmitter<String> {
        return DefaultLoadImpulseEmitter(initialImpulse: self.testStringLoadImpulse)
    }

    private func cacheDatasource(persistedState: State<String, String, TestDatasourceError>,
                                 loadImpulseEmitter: AnyLoadImpulseEmitter<String>)
        -> PlainCacheDatasource<String, String, TestDatasourceError> {

            let persister = TestStatePersister<String, String, TestDatasourceError>()
            persister.persist(persistedState)

            return PlainCacheDatasource<String, String, TestDatasourceError>(
                persister: persister.any,
                loadImpulseEmitter: loadImpulseEmitter,
                cacheLoadError: TestDatasourceError.cacheCouldNotLoad(.default)
            )
    }

    override func spec() {
        describe("CachedDatasource") {
            it("sends states to an observer") {

                let loadImpulseEmitter = self.loadImpulseEmitter().any
                let primaryDatasource = OneTwoThreeStringTestDatasource(loadImpulseEmitter: loadImpulseEmitter).any
                let cacheDatasource = self.cacheDatasource(persistedState: self.testStringState,
                                                           loadImpulseEmitter: primaryDatasource.loadImpulseEmitter)
                let datasource = CachedDatasource(loadImpulseEmitter: loadImpulseEmitter,
                                                  primaryDatasource: primaryDatasource,
                                                  cacheDatasource: cacheDatasource.any,
                                                  persister: cacheDatasource.persister)

                var observedStates: [State<String, String, TestDatasourceError>] = []

                let disposable = datasource.observe({ state in
                    observedStates.append(state)
                })

                OneTwoThreeStringTestDatasource.states.forEach({ state in
                    guard let loadImpulse = state.loadImpulse,
                        loadImpulse.parameters != OneTwoThreeStringTestDatasource.initialRequestParameter else {
                        return
                    }
                    loadImpulseEmitter.emit(loadImpulse)
                })

                disposable.dispose()

                expect(observedStates).to(contain(OneTwoThreeStringTestDatasource.states))
            }
            it("should release observer after disposal") {

                let loadImpulseEmitter = self.loadImpulseEmitter().any
                let primaryDatasource = OneTwoThreeStringTestDatasource(loadImpulseEmitter: loadImpulseEmitter).any
                let cacheDatasource = self.cacheDatasource(persistedState: self.testStringState,
                                                           loadImpulseEmitter: primaryDatasource.loadImpulseEmitter)
                let datasource = CachedDatasource(loadImpulseEmitter: loadImpulseEmitter,
                                                  primaryDatasource: primaryDatasource,
                                                  cacheDatasource: cacheDatasource.any,
                                                  persister: cacheDatasource.persister)
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

                datasource.loadImpulseEmitter.emit(LoadImpulse(parameters: "2"))
                expect(testStr) == "12"

                disposable.dispose()

                // Force synchronous access to disposable observers so assert works synchronously.
                // Alternatively, a wait or waitUntil assert could be used, but this is
                // less complex.
                expect(disposable.isDisposed) == true

                expect(testStr).to(beNil())
            }
            it("should release all resources on disposal") {

                weak var testStr: NSMutableString?

                struct Resources {
                    let disposable: Disposable
                    let loadImpulseEmitter: WeakReference<DefaultLoadImpulseEmitter<String>>
                    let primaryDatasource: WeakReference<OneTwoThreeStringTestDatasource>
                    let cacheDatasource: WeakReference<PlainCacheDatasource<String, String, TestDatasourceError>>
                    let cachedDatasource: WeakReference<CachedDatasource<String, String, TestDatasourceError>>

                    var isReleased: Bool {
                        return disposable.isDisposed && loadImpulseEmitter.isNil && primaryDatasource.isNil &&
                            cacheDatasource.isNil && cachedDatasource.isNil
                    }
                }

                let testScope: () -> Resources = {
                    let loadImpulseEmitter = self.loadImpulseEmitter()
                    let primaryDatasource = OneTwoThreeStringTestDatasource(loadImpulseEmitter: loadImpulseEmitter.any)
                    let cacheDatasource = self.cacheDatasource(persistedState: self.testStringState,
                                                               loadImpulseEmitter: primaryDatasource.loadImpulseEmitter)
                    let datasource = CachedDatasource(loadImpulseEmitter: loadImpulseEmitter.any,
                                                      primaryDatasource: primaryDatasource.any,
                                                      cacheDatasource: cacheDatasource.any,
                                                      persister: cacheDatasource.persister)

                    let innerStr = NSMutableString(string: "")
                    testStr = innerStr

                    let disposable = datasource.observe({ state in
                        if let value = state.value?.value {
                            innerStr.append(value)
                        }
                    })

                    return Resources(
                        disposable: disposable,
                        loadImpulseEmitter: WeakReference(loadImpulseEmitter),
                        primaryDatasource: WeakReference(primaryDatasource),
                        cacheDatasource: WeakReference(cacheDatasource),
                        cachedDatasource: WeakReference(datasource)
                    )
                }

                let resources = testScope()

                expect(resources.isReleased) == false

                expect(testStr) == "1"

                resources.disposable.dispose()

                // Force synchronous access to disposable observers so assert works synchronously.
                // Alternatively, a wait or waitUntil assert could be used, but this is
                // less complex.
                expect(resources.disposable.isDisposed) == true

                expect(resources.isReleased) == true
                expect(testStr).to(beNil())
            }
        }
    }

}
