import DataSourcerer
import Foundation

enum PublicReposCell {

    case repo(PublicRepo)
    case loading
    case error(APIError)
    case noResults

    enum ViewType: Int, ListItemViewType {
        case repo
        case loading
        case error
        case noResults

        var isSelectable: Bool {
            switch self {
            case .loading, .error, .noResults: return false
            case .repo: return true
            }
        }
    }
}

extension PublicReposCell: DefaultListItem {
    typealias DatasourceItem = PublicRepo
    typealias E = APIError

    var viewType: ViewType {
        switch self {
        case .repo: return .repo
        case .loading: return .loading
        case .error: return .error
        case .noResults: return .noResults
        }
    }

    init(errorMessage: String) {
        self = .error(APIError.unknown(description: errorMessage))
    }

    init(datasourceItem: PublicRepo) {
        self = .repo(datasourceItem)
    }

    static var loadingCell: PublicReposCell {
        return .loading
    }

    static var noResultsCell: PublicReposCell {
        return .noResults
    }

    static func errorCell(_ error: APIError) -> PublicReposCell {
        return PublicReposCell.error(error)
    }
}
