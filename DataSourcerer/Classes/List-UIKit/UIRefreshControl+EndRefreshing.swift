import Foundation
import UIKit

extension UIRefreshControl : SourcererExtensionsProvider {}

public extension SourcererExtension where Base: UIRefreshControl {

    func endRefreshingOnLoadingEnded<Value, P: ResourceParams, E: ResourceError>(
        _ datasource: Datasource<Value, P, E>
    ) -> Disposable {

        return datasource.state
            .loadingEnded()
            .observeOnUIThread()
            .observe { [weak base] _ in
                base?.endRefreshing()
            }
    }
}
