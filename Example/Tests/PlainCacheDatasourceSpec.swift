@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class PlainCacheDatasourceSpec: QuickSpec {

    private lazy var testStringLoadImpulse = LoadImpulse(parameters: "1")

    private lazy var testStringState: ResourceState<String, String, TestStateError> = {
        return ResourceState(
            provisioningState: .result,
            loadImpulse: testStringLoadImpulse,
            value: EquatableBox("1"),
            error: nil
        )
    }()

    private func testDatasource(persistedState: ResourceState<String, String, TestStateError>,
                                loadImpulseEmitter: SimpleLoadImpulseEmitter<String>)
        -> ValueStream<ResourceState<String, String, TestStateError>> {

            let persister = TestResourceStatePersister<String, String, TestStateError>()
            persister.persist(persistedState)

            return ValueStream(loadStatesFromPersister: persister.any,
                               loadImpulseEmitter: loadImpulseEmitter.any,
                               cacheLoadError: TestStateError.cacheCouldNotLoad(.default))
    }

    override func spec() {
        describe("PlainCacheDatasource") {
            it("should send stored value synchronously if initial load impulse is set") {
                let loadImpulseEmitter = SimpleLoadImpulseEmitter<String>(
                    initialImpulse: self.testStringLoadImpulse
                )
                let datasource = self.testDatasource(persistedState: self.testStringState,
                                                     loadImpulseEmitter: loadImpulseEmitter)
                var observedStates: [ResourceState<String, String, TestStateError>] = []

                let disposable = datasource.observe({ state in
                    observedStates.append(state)
                })

                disposable.dispose()

                expect(observedStates) == [self.testStringState]
            }
            it("should release observer after disposal") {
                let loadImpulseEmitter = SimpleLoadImpulseEmitter<String>(
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
