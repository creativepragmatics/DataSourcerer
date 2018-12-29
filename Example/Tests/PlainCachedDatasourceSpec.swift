@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class PlainCachedDatasourceSpec: QuickSpec {

    override func spec() {
        describe("PlainCachedDatasourceSpec") {
            it("should send stored value synchronously if initial load impulse is set") {

                let loadImpulse = LoadImpulse(parameters: "1")
                let state: State<String, String, TestDatasourceError> = State(provisioningState: .result,
                                                                              loadImpulse: loadImpulse,
                                                                              value: EquatableBox("stateValue"),
                                                                              error: nil)
                let persister = TestStatePersister<String, String, TestDatasourceError>()
                persister.persist(state)
                let loadImpulseEmitter = DefaultLoadImpulseEmitter<String>(emitOnFirstObservation: loadImpulse)
                let datasource = PlainCacheDatasource<String, String, TestDatasourceError>(
                    persister: persister.any,
                    loadImpulseEmitter: loadImpulseEmitter.any,
                    cacheLoadError: TestDatasourceError.cacheCouldNotLoad(.default)
                )

                var observedStates: [State<String, String, TestDatasourceError>] = []

                let disposable = datasource.observe({ state in
                    observedStates.append(state)
                })

                disposable.dispose()

                expect(observedStates) == [State<String, String, TestDatasourceError>.notReady, state]
            }
//            it("should release observer after disposal") {
//
//                weak var testStr: NSMutableString?
//                let emitter = DefaultLoadImpulseEmitter<String>(emitOnFirstObservation: nil)
//
//                let testScope: () -> Disposable = {
//                    let innerStr = NSMutableString(string: "")
//                    let disposable = emitter.observe({ loadImpulse in
//                        innerStr.append("\(loadImpulse.parameters)")
//                    })
//                    testStr = innerStr
//                    return disposable
//                }
//
//                let disposable = testScope()
//
//                emitter.emit(LoadImpulse(parameters: "1"))
//                expect(testStr) == "1"
//                emitter.emit(LoadImpulse(parameters: "2"))
//                expect(testStr) == "12"
//
//                disposable.dispose()
//
//                // Force sync access to observers so next assert works synchronously.
//                // Alternatively, a wait or waitUntil could be used, but this is
//                // less complex.
//                emitter.emit(LoadImpulse(parameters: "3"))
//
//                expect(testStr).to(beNil())
//            }
        }
    }

}
