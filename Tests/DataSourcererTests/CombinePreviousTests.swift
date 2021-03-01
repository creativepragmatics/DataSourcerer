@testable import DataSourcerer
import ReactiveSwift
import XCTest

class CombinePreviousTests: XCTestCase {
    func test_Success_Loading() throws {
        assertCombinePrevious(
            input: [success1, loading],
            output: [
                success1,
                ResourceType.State(
                    provisioningState: .loading,
                    loadImpulse: loading.loadImpulse,
                    value: success1.value,
                    error: nil
                )
            ]
        )
    }

    func test_Error_Loading() throws {
        assertCombinePrevious(
            input: [error1, loading],
            output: [
                error1,
                ResourceType.State(
                    provisioningState: .loading,
                    loadImpulse: loading.loadImpulse,
                    value: nil,
                    error: error1.error
                )
            ]
        )
    }

    func test_Success_Error_Loading() throws {
        func test(preferFallbackValueOverFallbackError: Bool) {
            assertCombinePrevious(
                input: [success1, error1, loading],
                output: [
                    success1,
                    error1.with(value: success1.value),
                    ResourceType.State(
                        provisioningState: .loading,
                        loadImpulse: loading.loadImpulse,
                        value: preferFallbackValueOverFallbackError ? success1.value : nil,
                        error: preferFallbackValueOverFallbackError ? nil : error1.error
                    )
                ],
                preferFallbackValueOverFallbackError: preferFallbackValueOverFallbackError
            )
        }
        test(preferFallbackValueOverFallbackError: true)
        test(preferFallbackValueOverFallbackError: false)
    }

    func test_Success_Error_Success_Loading() throws {
        assertCombinePrevious(
            input: [success1, error1, success2, loading],
            output: [
                success1,
                error1.with(value: success1.value),
                success2,
                ResourceType.State(
                    provisioningState: .loading,
                    loadImpulse: loading.loadImpulse,
                    value: success2.value,
                    error: nil
                )
            ]
        )
    }

    func test_Success_Error_NotReady_Loading() throws {
        assertCombinePrevious(
            input: [success1, error1, notReady, loading],
            output: [
                success1,
                error1.with(value: success1.value),
                notReady,
                loading
            ]
        )
    }

    func test_Error_Error_Loading() throws {
        assertCombinePrevious(
            input: [error1, error2, loading],
            output: [
                error1,
                error2,
                loading.with(error: error2.error)
            ]
        )
    }

    func test_Error_Success() throws {
        assertCombinePrevious(
            input: [error1, success1],
            output: [
                error1,
                success1
            ]
        )
    }

    func test_Error_NotReady_Success() throws {
        assertCombinePrevious(
            input: [error1, notReady, success1],
            output: [
                error1,
                notReady,
                success1
            ]
        )
    }

    func test_Success_Error() throws {
        assertCombinePrevious(
            input: [success1, error1],
            output: [
                success1,
                error1.with(value: success1.value)
            ]
        )
    }

    func test_Success_Success() throws {
        assertCombinePrevious(
            input: [success1, success2],
            output: [
                success1,
                success2
            ]
        )
    }

    func test_Error_Error() throws {
        assertCombinePrevious(
            input: [error1, error2],
            output: [
                error1,
                error2
            ]
        )
    }
}

private func assertCombinePrevious(
    input: [ResourceType.State],
    output: [ResourceType.State],
    preferFallbackValueOverFallbackError: Bool = true
) {
    let producer = SignalProducer(input)
        .combinePrevious(
            preferFallbackValueOverFallbackError: preferFallbackValueOverFallbackError
        )

    var received = [ResourceType.State]()
    producer.startWithValues { received.append($0) }

    XCTAssertEqual(
        received,
        output
    )
}

private typealias ResourceType = Resource<String, NoQuery, TestError>

private let success1 = ResourceType.State(
    provisioningState: .result,
    loadImpulse: ResourceType.LoadImpulse.initial,
    value: .init("success1"),
    error: nil
)

private let success2 = ResourceType.State(
    provisioningState: .result,
    loadImpulse: ResourceType.LoadImpulse.initial,
    value: .init("success2"),
    error: nil
)

private let error1 = ResourceType.State(
    provisioningState: .result,
    loadImpulse: ResourceType.LoadImpulse.initial,
    value: nil,
    error: .someError
)

private let error2 = ResourceType.State(
    provisioningState: .result,
    loadImpulse: ResourceType.LoadImpulse.initial,
    value: nil,
    error: .anotherError
)

private let loading = ResourceType.State(
    provisioningState: .loading,
    loadImpulse: ResourceType.LoadImpulse.initial,
    value: nil,
    error: nil
)

private let notReady = ResourceType.State(
    provisioningState: .notReady,
    loadImpulse: nil,
    value: nil,
    error: nil
)

private extension Resource.Cache
where Value == String, Query == NoQuery, Failure == TestError {
    static func successful() -> Self {
        .init(
            reader: .init(
                getCachedState: {
                    SignalProducer(value: Resource.State.cacheSuccessful($0))
                }
            ),
            persister: .init(
                persistCachedState: { _ in .empty }
            )
        )
    }

    static func successfulWithValue(_ property: Property<String>) -> Self {
        .init(
            reader: .init(
                getCachedState: {
                    SignalProducer(
                        value: Resource.State.cacheSuccessful($0, value: property.value)
                    )
                }
            ),
            persister: .init(
                persistCachedState: { _ in .empty }
            )
        )
    }
}

private extension Resource.State
where Value == String, Query == NoQuery, Failure == TestError {
    static func cacheSuccessful(
        _ loadImpulse: Resource.LoadImpulse,
        value: String = "cached"
    ) -> Self {
        .init(
            provisioningState: .result,
            loadImpulse: loadImpulse,
            value: .init(value),
            error: nil
        )
    }
}

private enum TestError: Error {
    case someError
    case anotherError
}
