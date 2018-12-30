@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class ObservableSpec: QuickSpec {

    override func spec() {
        describe("DefaultObservable") {
            it("should send values to an observer") {

                let observable = DefaultObservable<Int>(1)

                var observedValues: [Int] = []

                _ = observable.observe { value in
                    observedValues.append(value)
                }

                observable.emit(1)
                observable.emit(2)

                expect(observedValues) == [1,2]
            }
            it("should not duplicate values with multiple observers subscribed") {

                let observable = DefaultObservable<Int>(1)

                var observedValues: [Int] = []

                _ = observable.observe { value in
                    observedValues.append(value)
                }
                _ = observable.observe({ _ in })

                observable.emit(1)
                observable.emit(2)

                expect(observedValues) == [1,2]
            }
            it("should stop sending values to an observer after disposal") {

                let observable = DefaultObservable<Int>(1)

                var observedValues: [Int] = []

                let disposable = observable.observe { value in
                    observedValues.append(value)
                }

                observable.emit(1)
                observable.emit(2)
                disposable.dispose()
                observable.emit(3)

                expect(observedValues) == [1,2]
            }
            it("should release observer after disposal") {

                weak var testStr: NSMutableString?
                let observable = DefaultObservable<String>("")

                let testScope: () -> Disposable = {
                    let innerStr = NSMutableString(string: "")
                    let disposable = observable.observe { value in
                        innerStr.append("\(value)")
                    }
                    testStr = innerStr
                    return disposable
                }

                let disposable = testScope()

                observable.emit("1")
                expect(testStr) == "1"
                observable.emit("2")
                expect(testStr) == "12"

                disposable.dispose()

                // Force sync access to observers so next assert works synchronously.
                // Alternatively, a wait or waitUntil could be used, but this is
                // less complex.
                observable.emit("3")

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
}
