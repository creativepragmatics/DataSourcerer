@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class PlainCacheDatasourceSpec: QuickSpec {

    private lazy var testStringLoadImpulse = LoadImpulse(parameters: "1")

    private lazy var testStringState: State<String, String, TestDatasourceError> = {
        return State(
            provisioningState: .result,
            loadImpulse: testStringLoadImpulse,
            value: EquatableBox("1"),
            error: nil
        )
    }()

    private func testDatasource(persistedState: State<String, String, TestDatasourceError>,
                                loadImpulseEmitter: DefaultLoadImpulseEmitter<String>)
        -> PlainCacheDatasource<String, String, TestDatasourceError> {

        let persister = TestStatePersister<String, String, TestDatasourceError>()
        persister.persist(persistedState)

        return PlainCacheDatasource<String, String, TestDatasourceError>(
            persister: persister.any,
            loadImpulseEmitter: loadImpulseEmitter.any,
            cacheLoadError: TestDatasourceError.cacheCouldNotLoad(.default)
        )
    }

    override func spec() {
        describe("PlainCacheDatasource") {
            it("should send stored value synchronously if initial load impulse is set") {
                let loadImpulseEmitter = DefaultLoadImpulseEmitter<String>(
                    initialImpulse: self.testStringLoadImpulse
                )
                let datasource = self.testDatasource(persistedState: self.testStringState,
                                                     loadImpulseEmitter: loadImpulseEmitter)
                var observedStates: [State<String, String, TestDatasourceError>] = []

                let disposable = datasource.observe({ state in
                    observedStates.append(state)
                })

                disposable.dispose()

                expect(observedStates) == [State<String, String, TestDatasourceError>.notReady,
                                           self.testStringState]
            }
            it("should release observer after disposal") {
                let loadImpulseEmitter = DefaultLoadImpulseEmitter<String>(
                    initialImpulse: self.testStringLoadImpulse
                )
                let datasource = self.testDatasource(persistedState: self.testStringState,
                                                     loadImpulseEmitter: loadImpulseEmitter)

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

                loadImpulseEmitter.emit(LoadImpulse(parameters: "1"))
                expect(testStr) == "11"

                disposable.dispose()

                // Force synchronous access to disposable observers so assert works synchronously.
                // Alternatively, a wait or waitUntil assert could be used, but this is
                // less complex.
                expect(disposable.isDisposed) == true

                expect(testStr).to(beNil())
            }
        }
    }

}
