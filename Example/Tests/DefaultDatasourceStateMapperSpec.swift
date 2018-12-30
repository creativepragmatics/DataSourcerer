@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class DefaultDatasourceStateMapperSpec: QuickSpec {

    private lazy var testStringLoadImpulse = LoadImpulse(parameters: "1")

    private func testDatasource() -> OneTwoThreeStringTestDatasource {

        let initialImpulse = LoadImpulse(parameters: OneTwoThreeStringTestDatasource.initialRequestParameter)
        let loadImpulseEmitter = DefaultLoadImpulseEmitter<String>(initialImpulse: initialImpulse)
        return OneTwoThreeStringTestDatasource(loadImpulseEmitter: loadImpulseEmitter.any)
    }

    override func spec() {
        describe("DefaultDatasourceStateMapper") {
            it("should send mapped values to observer") {

                let datasource = self.testDatasource()

                let transform: (State<String, String, TestDatasourceError>) -> Int? = { state in
                    return (state.value).flatMap({ Int($0.value) })
                }

                let mapper = DefaultDatasourceStateMapper.init(datasource: datasource, stateToMappedValue: transform)

                var observedInts: [Int?] = []

                let disposable = mapper.observe({ value in
                    observedInts.append(value)
                })

                datasource.loadImpulseEmitter.emit(LoadImpulse(parameters: "2"))
                datasource.loadImpulseEmitter.emit(LoadImpulse(parameters: "3"))

                disposable.dispose()

                let expectedValues = OneTwoThreeStringTestDatasource.states.map(transform)
                expect(observedInts).to(contain(expectedValues))
            }
            it("should release observer after disposal") {

                let datasource = self.testDatasource()

                let transform: (State<String, String, TestDatasourceError>) -> Int? = { state in
                    return (state.value).flatMap({ Int($0.value) })
                }

                let mapper = DefaultDatasourceStateMapper.init(datasource: datasource, stateToMappedValue: transform)

                weak var testStr: NSMutableString?

                let testScope: () -> Disposable = {
                    let innerStr = NSMutableString(string: "")
                    let disposable = mapper.observe({ value in
                        if let string = value.map({ String($0) }) {
                            innerStr.append(string)
                        }
                    })
                    testStr = innerStr
                    return disposable
                }

                let disposable = testScope()
                expect(testStr) == "1"

                datasource.loadImpulseEmitter.emit(LoadImpulse(parameters: "1"))
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
