@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class SimpleDatasourceSpec: QuickSpec {

    override func spec() {
        describe("SimpleDatasource") {
            it("should send values to an observer") {

                let datasource = SimpleDatasource<Int>(1)

                var observedValues: [Int] = []

                _ = datasource.observe { value in
                    observedValues.append(value)
                }

                datasource.emit(2)

                expect(observedValues) == [1,2]
            }
            it("should not duplicate values with multiple observers subscribed") {

                let datasource = SimpleDatasource<Int>(1)

                var observedValues: [Int] = []

                _ = datasource.observe { value in
                    observedValues.append(value)
                }
                _ = datasource.observe({ _ in })

                datasource.emit(2)

                expect(observedValues) == [1,2]
            }
            it("should stop sending values to an observer after disposal") {

                let datasource = SimpleDatasource<Int>(1)

                var observedValues: [Int] = []

                let disposable = datasource.observe { value in
                    observedValues.append(value)
                }

                datasource.emit(2)
                disposable.dispose()
                datasource.emit(3)

                expect(observedValues) == [1,2]
            }
            it("should release observer after disposal") {

                weak var testStr: NSMutableString?
                let datasource = SimpleDatasource<String>("")

                let testScope: () -> Disposable = {
                    let innerStr = NSMutableString(string: "")
                    let disposable = datasource.observe { value in
                        innerStr.append("\(value)")
                    }
                    testStr = innerStr
                    return disposable
                }

                let disposable = testScope()

                datasource.emit("1")
                expect(testStr) == "1"
                datasource.emit("2")
                expect(testStr) == "12"

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

internal final class MutableReference<Value: AnyObject> {
    var value: Value?

    init(_ value: Value?) {
        self.value = value
    }
}

internal final class WeakReference<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value?) {
        self.value = value
    }

    var isNil: Bool {
        return value == nil
    }
}
