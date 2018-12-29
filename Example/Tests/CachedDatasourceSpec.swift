@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class CachedDatasourceSpec: QuickSpec {

    private lazy var testStringLoadImpulse = LoadImpulse(parameters: "1")

    private lazy var testStringState: State<String, String, TestDatasourceError> = {
        return State(
            provisioningState: .result,
            loadImpulse: testStringLoadImpulse,
            value: EquatableBox("1"),
            error: nil
        )
    }()

    private lazy var loadImpulseEmitter: DefaultLoadImpulseEmitter<String> = {
        return DefaultLoadImpulseEmitter(emitOnFirstObservation: self.testStringLoadImpulse)
    }()

    private func cacheDatasource(persistedState: State<String, String, TestDatasourceError>)
        -> PlainCacheDatasource<String, String, TestDatasourceError> {

            let persister = TestStatePersister<String, String, TestDatasourceError>()
            persister.persist(persistedState)

            let loadImpulseEmitter = DefaultLoadImpulseEmitter<String>(emitOnFirstObservation: persistedState.loadImpulse)
            return PlainCacheDatasource<String, String, TestDatasourceError>(
                persister: persister.any,
                loadImpulseEmitter: loadImpulseEmitter.any,
                cacheLoadError: TestDatasourceError.cacheCouldNotLoad(.default)
            )
    }

    private func datasource(primary: AnyDatasource<String, String, TestDatasourceError>, cached: PlainCacheDatasource<String, String, TestDatasourceError>)
        -> CachedDatasource<String, String, TestDatasourceError> {

            return CachedDatasource.init(loadImpulseEmitter: loadImpulseEmitter.any, primaryDatasource: primary, cacheDatasource: cached.any, persister: cached.persister)
    }

    override func spec() {
        describe("CachedDatasourceSpec") {
            it("sends a state to an observer") {

                let cacheDatasource = self.cacheDatasource(persistedState: self.testStringState)

                let datasource = self.datasource(primary: cacheDatasource.any, cached: cacheDatasource)

                var observedStates: [State<String, String, TestDatasourceError>] = []

                let disposable = datasource.observe({ state in
                    observedStates.append(state)
                })

                disposable.dispose()

                expect(observedStates) == [State<String, String, TestDatasourceError>.notReady,
                                           self.testStringState]
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
