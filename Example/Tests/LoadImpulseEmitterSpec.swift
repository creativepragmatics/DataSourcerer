@testable import DataSourcerer
import Foundation
import Nimble
import Quick

class LoadImpulseEmitterSpec: QuickSpec {

    override func spec() {
        describe("SimpleLoadImpulseEmitter") {
            it("should send initial load impulse to an observer") {

                let initialImpulse = LoadImpulse(params: "1")
                let emitter = SimpleLoadImpulseEmitter<String>(initialImpulse: initialImpulse)

                var observedImpulses: [LoadImpulse<String>] = []

                _ = emitter.observe({ loadImpulse in
                    observedImpulses.append(loadImpulse)
                })

                expect(observedImpulses) == [initialImpulse]
            }
            it("should send multiple load impulses to an observer") {

                let emitter = SimpleLoadImpulseEmitter<String>(initialImpulse: nil)

                var observedImpulses: [LoadImpulse<String>] = []

                _ = emitter.observe({ loadImpulse in
                    observedImpulses.append(loadImpulse)
                })

                let impulses = [LoadImpulse(params: "1"), LoadImpulse(params: "2")]
                impulses.forEach({ emitter.emit(loadImpulse: $0, on: .current) })

                expect(observedImpulses) == impulses
            }
            it("should not duplicate load impulses with multiple observers subscribed") {

                let emitter = SimpleLoadImpulseEmitter<String>(initialImpulse: nil)

                var observedImpulses: [LoadImpulse<String>] = []

                _ = emitter.observe({ loadImpulse in
                    observedImpulses.append(loadImpulse)
                })
                _ = emitter.observe({ _ in })

                let impulses = [LoadImpulse(params: "1"), LoadImpulse(params: "2")]
                impulses.forEach({ emitter.emit(loadImpulse: $0, on: .current) })

                expect(observedImpulses) == impulses
            }
            it("should release observer after disposal") {

                weak var testStr: NSMutableString?
                let emitter = SimpleLoadImpulseEmitter<String>(initialImpulse: nil)

                let testScope: () -> Disposable = {
                    let innerStr = NSMutableString(string: "")
                    let disposable = emitter.observe({ loadImpulse in
                        innerStr.append("\(loadImpulse.params)")
                    })
                    testStr = innerStr
                    return disposable
                }

                let disposable = testScope()

                emitter.emit(loadImpulse: LoadImpulse(params: "1"), on: .current)
                expect(testStr) == "1"
                emitter.emit(loadImpulse: LoadImpulse(params: "2"), on: .current)
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

extension String : ResourceParams {

    public func isCacheCompatible(_ candidate: String) -> Bool {
        return self.lowercased() == candidate.lowercased()
    }
}
