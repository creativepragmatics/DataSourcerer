import DataSourcerer
import DataSourcererUI
import DifferenceKit
import Foundation
import ReactiveSwift
import UIKit

struct MultiSectionViewModel {
    typealias PublicRepos = Resource<[PublicRepo], NoQuery, APIError>
    typealias BaseListBinding = PublicRepos.ListBinding<
        PublicRepoCell,
        RepoSection,
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
            initialLoadImpulse: .initial
        )

        self.listBinding = datasource
            .tableView
            .multiSection
            .enhanced
            .makeBinding(
                makeBaseSectionsWithResource: .constant {
                    repos, _ -> [ArraySection<RepoSection, PublicRepoCell>] in
                    let dict = Dictionary(grouping: repos, by: { String($0.name?.prefix(1) ?? "") })
                    return dict.keys.sorted().map {
                        firstChar -> ArraySection<RepoSection, PublicRepoCell> in
                        let repos = (dict[firstChar] ?? []).map(PublicRepoCell.repo)
                        return .init(model: RepoSection(title: firstChar), elements: repos)
                    }
                },
                makeBaseTableViewCell: .reusable(
                    UITableViewCell.self,
                    configure: { repo, cellView, tableView, indexPath in
                        cellView.textLabel?.text = {
                            switch repo {
                            case let .repo(repo): return repo.name
                            case .error: return nil
                            }
                        }()
                    }
                ),
                makeSectionHeader: .constant(
                    .make { sectionModel, indexPath, tableView -> BaseListBinding.SupplementaryView in
                        .uiView(
                            BaseListBinding.SupplementaryView.UIViewMaker(
                                makeView: {
                                    let label = UILabel()
                                    label.textAlignment = .center
                                    label.backgroundColor = UIColor.gray
                                    label.text = sectionModel.title
                                    return label
                                },
                                estimatedHeight: { 44 },
                                height: { 44 }
                            )
                        )
                    }
                ),
                makeSectionFooter: .constant(.none),
                errorsConfiguration: .constant(.alwaysShowError),
                makeLoadingTableViewCell: .reusable(LoadingTableViewCell.self),
                makeErrorTableViewCell: .reusable(ErrorTableViewCell.self, configure: { itemModel, cellView, _, _ in
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

struct RepoSection: Equatable {
    let title: String
    var differenceIdentifier: String { title }
}

extension RepoSection: SectionModel {
    init() {
        title = "Error occurred"
    }
}
