import DataSourcerer
import DifferenceKit
import Foundation
import ReactiveSwift
import UIKit

public extension Resource {

    /// Contains all data necessary to bind a `Datasource` to a list
    /// (e.g. UITableView or UICollectionView).
    ///
    /// Instead of instantiating a `ListBinding` directly, consider
    /// using the available builder patterns, e.g.:
    ///
    ///     datasource
    ///         .tableView
    ///         .singleSection
    ///         .enhanced
    ///         .makeBinding(...)
    struct ListBinding<
        ItemModelType: ItemModel,
        SectionModelType: SectionModel,
        View: UIView,
        ContainerView: UIView
    >
    where ItemModelType.Failure == FailureType {
        public typealias DiffableSection = ArraySection<SectionModelType, ItemModelType>

        public let datasource: Datasource
        public let listViewStateMaker: Property<ListViewStateMaker>
        public let listViewState: Property<ListViewState>
        public let itemViewMaker: Property<UIViewItemMaker>

        public let didSelectItem = Signal<ItemSelection, Never>.pipe()
        public let willUpdateListView = Signal<ListViewStateChange, Never>.pipe()
        public let didUpdateListView = Signal<ListViewStateChange, Never>.pipe()
        public let willDisplayItem = Signal<ItemSelection, Never>.pipe()

        /// Section headers/footers (titles), or supplementary views for items
        public var supplementaryViewMaker: Property<SupplementaryViewMaker>
    }
}

public extension Resource.ListBinding {
    struct ItemSelection {
        public let itemModel: ItemModelType
        public let view: View
        public let indexPath: IndexPath
        public let containingView: ContainerView
    }

    struct ListViewStateChange {
        public let previousState: ListViewState
        public let nextState: ListViewState
        public let containingView: ContainerView
    }

    struct SupplementaryViewParams {
        public let kind: SupplementaryViewKind
        public let indexPath: IndexPath
        public let containingView: ContainerView
    }

    enum SupplementaryView {
        case none
        case title(String)
        case uiView(UIViewMaker)

        public struct UIViewMaker {
            public let makeView: () -> UIView
            public let estimatedHeight: (() -> CGFloat)?
            public let height: (() -> CGFloat)?

            public init(
                makeView: @escaping () -> UIView,
                estimatedHeight: (() -> CGFloat)?,
                height: (() -> CGFloat)?
            ) {
                self.makeView = makeView
                self.estimatedHeight = estimatedHeight
                self.height = height
            }
        }
    }

    struct SupplementaryViewMaker {
        let make: (SupplementaryViewParams) -> SupplementaryView

        public init(make: @escaping (SupplementaryViewParams) -> SupplementaryView) {
            self.make = make
        }
    }

    enum SupplementaryViewKind {
        case sectionHeader(SectionModelType)
        case sectionFooter(SectionModelType)
        case item(ItemModelType)
    }
}
