import Foundation
import ReactiveSwift
import UIKit

extension UIRefreshControl: SourcererExtensionsProvider {}

public extension SourcererExtension where Base: UIRefreshControl {
    func endRefreshing(when refreshingEnded: Signal<Void, Never>) -> Disposable? {
        refreshingEnded.observeValues { _ in
            base.endRefreshing()
        }
    }
}
