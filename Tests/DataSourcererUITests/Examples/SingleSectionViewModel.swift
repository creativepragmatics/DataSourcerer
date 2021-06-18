import DataSourcerer
import DataSourcererUI
import Foundation
import ReactiveSwift
import UIKit

struct SingleSectionViewModel {
    typealias PublicRepos = Resource<[PublicRepo], NoQuery, APIError>
    typealias ListBinding = PublicRepos.ListBinding<
        PublicRepoCell,
        SingleSection,
        UITableViewCell,
        UITableView
    >.EnhancedListBinding

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

        let sortAscendingStorage = MutableProperty(true)
        let sortAscending = SignalProducer
            .timer(interval: .seconds(1), on: QueueScheduler.main)
            .map { _ -> Bool in
                sortAscendingStorage.value = !sortAscendingStorage.value
                return sortAscendingStorage.value
            }
        let sortAscendingProperty = Property(initial: sortAscendingStorage.value, then: sortAscending)


        self.listBinding = datasource
            .tableView
            .singleSection
            .enhanced
            .makeBinding(
                makeBaseModelsWithResource: sortAscendingProperty.map { ascending in
                    { repos, _ in
                        repos
                            .prefix(10)
                            .sorted {
                                ascending ?
                                    ($0.name ?? "") < ($1.name ?? "") :
                                    ($0.name ?? "") > ($1.name ?? "")
                            }
                            .map(PublicRepoCell.repo)
                    }
                },
                makeBaseTableViewCell: .reusable(
                    UITableViewCell.self,
                    update: { repo, cellView, tableView, indexPath in
                        cellView.textLabel?.text = {
                            switch repo {
                            case let .repo(repo): return repo.name
                            case .error: return nil
                            }
                        }()
                    }
                ),
                errorsConfiguration: .constant(.alwaysShowError),
                makeLoadingTableViewCell: .reusable(LoadingTableViewCell.self),
                makeErrorTableViewCell: .reusable(ErrorTableViewCell.self, update: { itemModel, cellView, _, _ in
                    switch itemModel {
                    case let .error(error):
                        (cellView as? ErrorTableViewCell)?.content = error.errorMessage
                    case .baseItem, .loading, .noResults:
                        break
                    }
                }),
                makeNoResultsTableViewCell: .reusable(NoResultsTableViewCell.self)
            )
    }
}
