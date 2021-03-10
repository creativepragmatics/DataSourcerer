import Foundation
@testable import MulticastDelegate
import UIKit
import XCTest

class MulticastDelegateTests: XCTestCase {

    func test_Active_Inactive() {
        let (a, b) = (ActiveDelegate(), InactiveDelegate())
        let multicastDelegate = MulticastDelegate(delegates: [a, b])
        (multicastDelegate as UITableViewDelegate).tableView?(UITableView(), didSelectRowAt: IndexPath())
        XCTAssertTrue(a.didSelectCalled)
    }

    func test_Active_Active() {
        let (a, b) = (ActiveDelegate(), ActiveDelegate())
        let multicastDelegate = MulticastDelegate(delegates: [a, b])
        (multicastDelegate as UITableViewDelegate).tableView?(UITableView(), didSelectRowAt: IndexPath())
        XCTAssertTrue(a.didSelectCalled)
        XCTAssertTrue(b.didSelectCalled)
    }

    func test_Inactive_Inactive() {
        let (a, b) = (InactiveDelegate(), InactiveDelegate())
        let multicastDelegate = MulticastDelegate(delegates: [a, b])
        let responds = multicastDelegate.responds(
            to: #selector(UITableViewDelegate.tableView(_:didSelectRowAt:))
        )
        XCTAssertFalse(responds)
    }

}

class ActiveDelegate: NSObject, UITableViewDelegate {
    var didSelectCalled = false

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectCalled = true
    }
}

class InactiveDelegate: NSObject, UITableViewDelegate {}

extension MulticastDelegate: UITableViewDelegate {}
