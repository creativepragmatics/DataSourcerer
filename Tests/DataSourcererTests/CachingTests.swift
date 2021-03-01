import XCTest
@testable import DataSourcerer
import ReactiveSwift

class CachingTests: XCTestCase {

    private typealias ResourceType = Resource<String, NoQuery, TestError>

    func testAPIResultOverridesCacheResult() throws {
        let makeApiRequest = { (_: ResourceType.LoadImpulse) in
            SignalProducer(value: "API")
                .promoteError(TestError.self)
        }

        let datasource = ResourceType.Datasource(
            makeApiRequest: makeApiRequest,
            cache: ResourceType.Cache.successful(),
            initialLoadImpulse: .initial
        )

        XCTAssertEqual(datasource.state.value.value?.value, "API")
    }

    func testCacheResultIsUsedIfNoAPIResult() throws {
        let makeApiRequest = { (_: ResourceType.LoadImpulse) in
            SignalProducer<String, TestError>.empty
        }

        let datasource = ResourceType.Datasource(
            makeApiRequest: makeApiRequest,
            cache: ResourceType.Cache.successful(),
            initialLoadImpulse: .initial
        )

        XCTAssertEqual(datasource.state.value.value?.value, "cached")
    }

    func testCacheResultIsUsedIfAPIError() throws {
        let makeApiRequest = { (_: ResourceType.LoadImpulse) in
            SignalProducer<String, TestError>(error: .someError)
        }

        let datasource = ResourceType.Datasource(
            makeApiRequest: makeApiRequest,
            cache: ResourceType.Cache.successful(),
            initialLoadImpulse: .initial
        )

        XCTAssertEqual(datasource.state.value.value?.value, "cached")
        XCTAssertEqual(datasource.state.value.error, .someError)
    }

    func testAPIResultIsUsedAfterAPIErrorFollowedBySuccess() throws {
        let sendAPIError = MutableProperty(true)

        let makeApiRequest = { (_: ResourceType.LoadImpulse)
            -> SignalProducer<String, TestError> in
            if sendAPIError.value {
                return .init(error: .someError)
            } else {
                return .init(value: "API")
            }
        }

        let datasource = ResourceType.Datasource(
            makeApiRequest: makeApiRequest,
            cache: ResourceType.Cache.successful(),
            initialLoadImpulse: .initial
        )

        XCTAssertEqual(datasource.state.value.value?.value, "cached")
        XCTAssertEqual(datasource.state.value.error, .someError)

        sendAPIError.value = false
        datasource.refresh(skipIfResultAvailable: true).start()

        XCTAssertEqual(datasource.state.value.value?.value, "API")
        XCTAssertEqual(datasource.state.value.error, nil)
    }

    func testCacheResultIsUpdatedOnSecondAPIError() throws {
        let cacheValue = MutableProperty("cached1")

        let makeApiRequest = { (_: ResourceType.LoadImpulse) in
            SignalProducer<String, TestError>(error: .someError)
        }

        let datasource = ResourceType.Datasource(
            makeApiRequest: makeApiRequest,
            cache: ResourceType.Cache.successfulWithValue(Property(capturing: cacheValue)),
            initialLoadImpulse: .initial
        )

        XCTAssertEqual(datasource.state.value.value?.value, "cached1")
        XCTAssertEqual(datasource.state.value.error, .someError)

        cacheValue.value = "cached2"
        datasource.refresh(skipIfResultAvailable: true).start()

        XCTAssertEqual(datasource.state.value.value?.value, "cached2")
        XCTAssertEqual(datasource.state.value.error, .someError)
    }
}

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
}
