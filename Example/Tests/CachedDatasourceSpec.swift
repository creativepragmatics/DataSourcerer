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

    private lazy var loadImpulseEmitter: DefaultLoadImpulseEmitter<String> = {
        return DefaultLoadImpulseEmitter(initialImpulse: self.testStringLoadImpulse)
    }()

    private func cacheDatasource(persistedState: State<String, String, TestDatasourceError>)
        -> PlainCacheDatasource<String, String, TestDatasourceError> {

            let persister = TestStatePersister<String, String, TestDatasourceError>()
            persister.persist(persistedState)

            let loadImpulseEmitter = DefaultLoadImpulseEmitter<String>(initialImpulse: persistedState.loadImpulse)
            return PlainCacheDatasource<String, String, TestDatasourceError>(
                persister: persister.any,
                loadImpulseEmitter: loadImpulseEmitter.any,
                cacheLoadError: TestDatasourceError.cacheCouldNotLoad(.default)
            )
    }

    private func primaryDatasource() -> OneTwoThreeStringTestDatasource {

        return OneTwoThreeStringTestDatasource(loadImpulseEmitter: self.loadImpulseEmitter.any)
    }

    private func datasource(primary: AnyDatasource<String, String, TestDatasourceError>, cached: PlainCacheDatasource<String, String, TestDatasourceError>)
        -> CachedDatasource<String, String, TestDatasourceError> {

            return CachedDatasource.init(loadImpulseEmitter: loadImpulseEmitter.any, primaryDatasource: primary, cacheDatasource: cached.any, persister: cached.persister)
    }

    override func spec() {
        describe("CachedDatasourceSpec") {
            it("sends states to an observer") {

                let cacheDatasource = self.cacheDatasource(persistedState: self.testStringState)
                let datasource = self.datasource(primary: self.primaryDatasource().any, cached: cacheDatasource)
                var observedStates: [State<String, String, TestDatasourceError>] = []

                let disposable = datasource.observe({ state in
                    observedStates.append(state)
                })

                OneTwoThreeStringTestDatasource.states.forEach({ state in
                    guard let loadImpulse = state.loadImpulse,
                        loadImpulse.parameters != OneTwoThreeStringTestDatasource.initialRequestParameter else {
                        return
                    }
                    self.loadImpulseEmitter.emit(loadImpulse)
                })

                disposable.dispose()

                expect(observedStates).to(contain(OneTwoThreeStringTestDatasource.states))
            }
//            it("should release observer after disposal") {
//
//                let datasource = self.testDatasource(persistedState: self.testStringState)
//
//                weak var testStr: NSMutableString?
//
//                let testScope: () -> Disposable = {
//                    let innerStr = NSMutableString(string: "")
//                    let disposable = datasource.observe({ state in
//                        if let value = state.value?.value {
//                            innerStr.append(value)
//                        }
//                    })
//                    testStr = innerStr
//                    return disposable
//                }
//
//                let disposable = testScope()
//                expect(testStr) == "1"
//
//                datasource.loadImpulseEmitter.emit(LoadImpulse(parameters: "1"))
//                expect(testStr) == "11"
//
//                disposable.dispose()
//
//                // Force sync access to observers so next assert works synchronously.
//                // Alternatively, a wait or waitUntil could be used, but this is
//                // less complex.
//                datasource.loadImpulseEmitter.emit(LoadImpulse(parameters: "1"))
//
//                expect(testStr).to(beNil())
//            }
        }
    }

}
