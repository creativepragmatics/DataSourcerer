import DataSourcerer
import Foundation

public extension Resource.ListBinding.SupplementaryViewMaker {
    typealias EnhancedListBinding = Resource.ListBinding<
        EnhancedItemModel<ItemModelType>,
        SectionModelType,
        View,
        ContainerView
    >

    func enhance() -> EnhancedListBinding.SupplementaryViewMaker {
        .init { (enhancedParams: EnhancedListBinding.SupplementaryViewParams)
            -> EnhancedListBinding.SupplementaryView in
            switch enhancedParams.kind {
            case let .sectionHeader(sectionModel):
                return make(
                    .init(
                        kind: .sectionHeader(sectionModel),
                        indexPath: enhancedParams.indexPath,
                        containingView: enhancedParams.containingView
                    )
                )
                .enhance()
            case let .sectionFooter(sectionModel):
                return make(
                    .init(
                        kind: .sectionFooter(sectionModel),
                        indexPath: enhancedParams.indexPath,
                        containingView: enhancedParams.containingView
                    )
                )
                .enhance()
            case let .item(item):
                switch item {
                case let .baseItem(baseItem):
                    return make(
                        .init(
                            kind: .item(baseItem),
                            indexPath: enhancedParams.indexPath,
                            containingView: enhancedParams.containingView
                        )
                    )
                    .enhance()
                case .error, .loading, .noResults:
                    return .none
                }
            }
        }
    }
}

public extension Resource.ListBinding.SupplementaryView {
    typealias EnhancedListBinding = Resource.ListBinding<
        EnhancedItemModel<ItemModelType>,
        SectionModelType,
        View,
        ContainerView
    >

    func enhance() -> EnhancedListBinding.SupplementaryView {
        switch self {
        case .none:
            return .none
        case let .title(string):
            return .title(string)
        case let .uiView(uiViewMaker):
            return .uiView(
                .init(
                    makeView: uiViewMaker.makeView,
                    estimatedHeight: uiViewMaker.estimatedHeight,
                    height: uiViewMaker.height
                )
            )
        }
    }
}
