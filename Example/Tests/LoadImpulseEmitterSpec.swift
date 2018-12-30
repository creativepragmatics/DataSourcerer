@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class LoadImpulseEmitterSpec: QuickSpec {

    override func spec() {
        describe("DefaultLoadImpulseEmitter") {
            it("should send initial load impulse to an observer") {

                let initialImpulse = LoadImpulse(parameters: "1")
                let emitter = DefaultLoadImpulseEmitter<String>(initialImpulse: initialImpulse)

                var observedImpulses: [LoadImpulse<String>] = []

                _ = emitter.observe({ loadImpulse in
                    observedImpulses.append(loadImpulse)
                })

                expect(observedImpulses) == [initialImpulse]
            }
            it("should send multiple load impulses to an observer") {

                let emitter = DefaultLoadImpulseEmitter<String>(initialImpulse: nil)

                var observedImpulses: [LoadImpulse<String>] = []

                _ = emitter.observe({ loadImpulse in
                    observedImpulses.append(loadImpulse)
                })

                let impulses = [LoadImpulse(parameters: "1"), LoadImpulse(parameters: "2")]
                impulses.forEach({ emitter.emit($0) })

                expect(observedImpulses) == impulses
            }
            it("should not duplicate load impulses with multiple observers subscribed") {

                let emitter = DefaultLoadImpulseEmitter<String>(initialImpulse: nil)

                var observedImpulses: [LoadImpulse<String>] = []

                _ = emitter.observe({ loadImpulse in
                    observedImpulses.append(loadImpulse)
                })
                _ = emitter.observe({ _ in })

                let impulses = [LoadImpulse(parameters: "1"), LoadImpulse(parameters: "2")]
                impulses.forEach({ emitter.emit($0) })

                expect(observedImpulses) == impulses
            }
            it("should release observer after disposal") {

                weak var testStr: NSMutableString?
                let emitter = DefaultLoadImpulseEmitter<String>(initialImpulse: nil)

                let testScope: () -> Disposable = {
                    let innerStr = NSMutableString(string: "")
                    let disposable = emitter.observe({ loadImpulse in
                        innerStr.append("\(loadImpulse.parameters)")
                    })
                    testStr = innerStr
                    return disposable
                }

                let disposable = testScope()

                emitter.emit(LoadImpulse(parameters: "1"))
                expect(testStr) == "1"
                emitter.emit(LoadImpulse(parameters: "2"))
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

extension String : Parameters {

    public func isCacheCompatible(_ candidate: String) -> Bool {
        return self.lowercased() == candidate.lowercased()
    }
}
