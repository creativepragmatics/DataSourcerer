@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class DatasourceOperationsSpec: QuickSpec {

    private lazy var testStringLoadImpulse = LoadImpulse(parameters: "1")

    var stringLoadImpulseEmitter: AnyLoadImpulseEmitter<String> {
        return SimpleLoadImpulseEmitter<String>(initialImpulse: testStringLoadImpulse).any
    }

    private func testDatasource(_ loadImpulseEmitter: AnyLoadImpulseEmitter<String>)
        -> ValueStream<ResourceState<String, String, TestStateError>> {

            return ValueStream(testStates: OneTwoThreeStringTestStates.oneTwoThreeStringStates,
                               testError: TestStateError.unknown(description: "Value unavailable"),
                               loadImpulseEmitter: loadImpulseEmitter)
    }

    override func spec() {
        describe("Datasource.map") {
            it("should send mapped values to observer") {

                let loadImpulseEmitter = self.stringLoadImpulseEmitter
                let datasource = self.testDatasource(loadImpulseEmitter)

                let transform: (ResourceState<String, String, TestStateError>) -> Int? = { state in
                    return (state.value).flatMap({ Int($0.value) })
                }

                let mapped = datasource.map(transform)

                var observedInts: [Int?] = []

                let disposable = mapped.observe({ value in
                    observedInts.append(value)
                })

                loadImpulseEmitter.emit(LoadImpulse(parameters: "2"))
                loadImpulseEmitter.emit(LoadImpulse(parameters: "3"))

                disposable.dispose()

                let expectedValues = OneTwoThreeStringTestStates.oneTwoThreeStringStates.map(transform)
                expect(observedInts).to(contain(expectedValues))
            }
            it("should release observer after disposal") {

                let loadImpulseEmitter = self.stringLoadImpulseEmitter
                let datasource = self.testDatasource(loadImpulseEmitter)

                let transform: (ResourceState<String, String, TestStateError>) -> Int? = { state in
                    return (state.value).flatMap({ Int($0.value) })
                }

                let mapped = datasource.map(transform)

                weak var testStr: NSMutableString?

                let testScope: () -> Disposable = {
                    let innerStr = NSMutableString(string: "")
                    let disposable = mapped.observe({ value in
                        if let string = value.map({ String($0) }) {
                            innerStr.append(string)
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
