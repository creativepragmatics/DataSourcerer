import DataSourcerer
import DataSourcererUI
import DifferenceKit
import Foundation
import ReactiveSwift
import UIKit

struct MultiViewTypeSingleSectionViewModel {
    typealias PublicRepos = Resource<[PublicRepo], NoQuery, APIError>
    typealias BaseListBinding = PublicRepos.ListBinding<
        PublicRepoCell,
        SingleSection,
        UITableViewCell,
        UITableView
    >
    typealias ListBinding = BaseListBinding.EnhancedListBinding

    let datasource: PublicRepos.Datasource
    let listBinding: ListBinding

    init() {
        datasource = PublicRepos.Datasource(
            makeApiRequest: { loadImpulse -> SignalProducer<PublicRepos.ValueType, APIError> in
                let url = URL(string: "https://api.github.com/repositories")!
                return PublicRepos.loadURLRequest(URLRequest(url: url))
            },
            cache: nil,
            systemLoadImpulses: .makeInitialLoadImpulse()
        )

        self.listBinding = datasource
            .tableView
            .singleSection
            .enhanced
            .makeBinding(
                makeBaseModelsWithResource: .constant { repos, _ -> [PublicRepoCell] in
                    repos.map(PublicRepoCell.repo)
                },
                makeMultiBaseTableViewCells: { viewType in
                    switch viewType {
                    case .cellTypeA:
                        return .reusable(
                            UITableViewCell.self,
                            update: { repo, cellView, tableView, indexPath in
                                cellView.textLabel?.text = {
                                    switch repo {
                                    case let .repo(repo): return repo.name
                                    case .error: return nil
                                    }
                                }()
                            }
                        )
                    case .cellTypeB:
                        return .reusable(
                            AlternativeTableViewCell.self,
                            update: { repo, cellView, tableView, indexPath in
                                (cellView as? AlternativeTableViewCell)?.label.text = {
                                    switch repo {
                                    case let .repo(repo): return repo.name
                                    case .error: return nil
                                    }
                                }()
                            }
                        )
                    }
                },
                errorsConfiguration: .constant(.alwaysShowError),
                makeLoadingTableViewCell: .reusable(LoadingTableViewCell.self),
                makeErrorTableViewCell: .reusable(
                    ErrorTableViewCell.self,
                    update: { itemModel, cellView, _, _ in
                        switch itemModel {
                        case let .error(error):
                            (cellView as? ErrorTableViewCell)?.content = error.errorMessage
                        case .baseItem, .loading, .noResults:
                            break
                        }
                    }
                ),
                makeNoResultsTableViewCell: .reusable(NoResultsTableViewCell.self)
            )
    }
}
