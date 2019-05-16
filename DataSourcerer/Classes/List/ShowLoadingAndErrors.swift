import Foundation

public struct ShowLoadingAndErrorsConfiguration {
    public let errorsConfiguration: ErrorsConfiguration

    public init(errorsConfiguration: ErrorsConfiguration) {
        self.errorsConfiguration = errorsConfiguration
    }

    public enum ErrorsConfiguration {
        case alwaysShowError
        case ignoreErrorIfCachedValueAvailable
    }
}

public enum IdiomaticItemModel<BaseItem: ItemModel> : ItemModel {
    case baseItem(BaseItem)
    case loading
    case error(BaseItem.E)
    case noResults(String)

    public init(error: BaseItem.E) {
        self = .error(error)
    }
}

public extension ResourceState {

    /// Returns cells according to the `state` and the given `valueToItems` closure.
    /// If no values are currently available, return nil in valueToItems to
    /// show an item generated by `noResultsItemGenerator`/`errorItemGenerator`/`loadingCellGenerator`
    /// instead.
    func addLoadingAndErrorStates<BaseItemModelType: ItemModel, SectionModelType: SectionModel>(
        configuration: ShowLoadingAndErrorsConfiguration,
        valueToIdiomaticListViewStateTransformer: ValueToListViewStateTransformer
            <Value, P, E, IdiomaticItemModel<BaseItemModelType>, SectionModelType>,
        loadingSection:
            @escaping (ResourceState)
            -> SectionAndItems<IdiomaticItemModel<BaseItemModelType>, SectionModelType>,
        errorSection:
            @escaping (E)
            -> SectionAndItems<IdiomaticItemModel<BaseItemModelType>, SectionModelType>,
        noResultsSection:
            @escaping (ResourceState)
            -> SectionAndItems<IdiomaticItemModel<BaseItemModelType>, SectionModelType>
    ) -> ListViewState<Value, P, E, IdiomaticItemModel<BaseItemModelType>, SectionModelType>
        where BaseItemModelType.E == E {

            guard let loadImpulse = self.loadImpulse else {
                return ListViewState<Value, P, E, IdiomaticItemModel<BaseItemModelType>, SectionModelType>.notReady
            }

            func boxedValueToSections(_ box: EquatableBox<Value>?)
                -> [SectionAndItems<IdiomaticItemModel<BaseItemModelType>, SectionModelType>]? {

                    return (box?.value).flatMap { value
                        -> [SectionAndItems<IdiomaticItemModel<BaseItemModelType>, SectionModelType>]? in

                        return valueToIdiomaticListViewStateTransformer.valueToListViewState(
                            value,
                            self
                        ).sectionsAndItems
                    }
            }

            func numberOfItems(
                _ sections: [SectionAndItems<IdiomaticItemModel<BaseItemModelType>, SectionModelType>]
                ) -> Int {
                return sections.map({ $0.items.count }).reduce(0, +)
            }

            var noResults: ListViewState<Value, P, E, IdiomaticItemModel<BaseItemModelType>, SectionModelType> {
                return ListViewState.readyToDisplay(
                    self,
                    [noResultsSection(self)]
                )
            }

            var empty: ListViewState<Value, P, E, IdiomaticItemModel<BaseItemModelType>, SectionModelType> {
                return ListViewState.readyToDisplay(
                    self,
                    [SectionAndItems(SectionModelType(), [])]
                )
            }

            func showError(_ error: E)
                -> ListViewState<Value, P, E, IdiomaticItemModel<BaseItemModelType>, SectionModelType> {
                    return ListViewState.readyToDisplay(
                        self,
                        [errorSection(error)]
                    )
            }

            var loading: ListViewState<Value, P, E, IdiomaticItemModel<BaseItemModelType>, SectionModelType> {
                return ListViewState.readyToDisplay(
                    self,
                    [loadingSection(self)]
                )
            }

            switch provisioningState {
            case .notReady:
                return ListViewState<Value, P, E, IdiomaticItemModel<BaseItemModelType>, SectionModelType>.notReady
            case .loading:
                if let sections = boxedValueToSections(value), numberOfItems(sections) > 0 {
                    // Loading and there are fallback items, return them
                    return ListViewState.readyToDisplay(
                        self,
                        sections
                    )
                } else if self.error != nil {
                    // Loading, error, and there are no fallback items > return loading item
                    // if the loadImpulse permits it, or if no loadImpulse available (== .notReady)
                    if self.loadImpulse?.type.showLoadingIndicator ?? true {
                        return loading
                    } else {
                        return empty
                    }
                } else if value != nil {
                    // Loading and there is an empty fallback balue, return noResults item.
                    // We could also just display only the loadingSection instead, but then the view
                    // would e.g. jump from noResults to loading-only to noResults. While technically
                    // correct, keeping noResults is less irritating.
                    return noResults
                } else {
                    // Loading and there are no fallback items, return loading item
                    if self.loadImpulse?.type.showLoadingIndicator ?? true {
                        return loading
                    } else {
                        return empty
                    }
                }
            case .result:
                switch configuration.errorsConfiguration {
                case .alwaysShowError:
                    if let error = self.error {
                        return showError(error)
                    } else if let value = self.value {
                        if let sections = boxedValueToSections(value), numberOfItems(sections) > 0 {
                            // Success, return items
                            return ListViewState.readyToDisplay(
                                self,
                                sections
                            )
                        } else {
                            // Success without items, return noResults
                            return noResults
                        }
                    } else {
                        // No error and no value, return noResults
                        return noResults
                    }
                case .ignoreErrorIfCachedValueAvailable:
                    if let value = self.value {
                        if let sections = boxedValueToSections(value), numberOfItems(sections) > 0 {
                            // Success, return items
                            return ListViewState.readyToDisplay(
                                self,
                                sections
                            )
                        } else {
                            // Success without items, return noResults
                            return noResults
                        }
                    } else if let error = self.error {
                        return showError(error)
                    } else {
                        // No error and no value, return noResults
                        return noResults
                    }
                }
            }
    }

    /// Convenience
    func addLoadingAndErrorStates<BaseItemModelType, SectionModelType: SectionModel>(
        configuration: ShowLoadingAndErrorsConfiguration,
        valueToIdiomaticListViewStateTransformer: ValueToListViewStateTransformer
            <Value, P, E, IdiomaticItemModel<BaseItemModelType>, SectionModelType>,
        noResultsText: String
    ) -> ListViewState<Value, P, E, IdiomaticItemModel<BaseItemModelType>, SectionModelType>
        where BaseItemModelType.E == E {

            return addLoadingAndErrorStates(
                configuration: configuration,
                valueToIdiomaticListViewStateTransformer: valueToIdiomaticListViewStateTransformer,
                loadingSection: { _ in SectionAndItems(SectionModelType(), [IdiomaticItemModel.loading]) },
                errorSection: { SectionAndItems(SectionModelType(), [IdiomaticItemModel.error($0)]) },
                noResultsSection: { _ in
                    SectionAndItems(SectionModelType(), [IdiomaticItemModel.noResults(noResultsText)])
                }
            )
    }

}

public extension ItemViewsProducer {

    func showLoadingAndErrorStates<ViewProducer: ItemViewProducer>(
        configuration: ShowLoadingAndErrorsConfiguration,
        loadingViewProducer: ViewProducer,
        errorViewProducer: ViewProducer,
        noResultsViewProducer: ViewProducer
    ) -> ItemViewsProducer<IdiomaticItemModel<ItemModelType>, ProducedView, ContainingView>
        where ViewProducer.ItemModelType == IdiomaticItemModel<ItemModelType>,
        ViewProducer.ContainingView == ContainingView,
        ViewProducer.ProducedView == ProducedView {

            return ItemViewsProducer<IdiomaticItemModel<ItemModelType>, ProducedView, ContainingView>(
                produceView: { item, containingView, indexPath -> ProducedView in
                    switch item {
                    case let .baseItem(baseItem):
                        return self.produceView(baseItem, containingView, indexPath)
                    case let .error(error):
                        return errorViewProducer.view(containingView: containingView,
                                                      item: .error(error),
                                                      for: indexPath)
                    case .loading:
                        return loadingViewProducer.view(containingView: containingView,
                                                        item: .loading,
                                                        for: indexPath)
                    case let .noResults(noResultsText):
                        return noResultsViewProducer.view(containingView: containingView,
                                                          item: .noResults(noResultsText),
                                                          for: indexPath)
                    }
                },
                registerAtContainingView: { containingView in
                    self.registerAtContainingView(containingView)
                    loadingViewProducer.register(at: containingView)
                    errorViewProducer.register(at: containingView)
                    noResultsViewProducer.register(at: containingView)
                }
            )
    }
}

public extension ItemModelsProducer {
    
    func showLoadingAndErrorStates(
        configuration: ShowLoadingAndErrorsConfiguration,
        noResultsText: String
    ) -> ItemModelsProducer<Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType> {

        return ItemModelsProducer<Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType>(
            stateToListViewState: { state, valueToIdiomaticListViewStateTransformer
                -> ListViewState<Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType> in

                return state.addLoadingAndErrorStates(
                    configuration: configuration,
                    valueToIdiomaticListViewStateTransformer: valueToIdiomaticListViewStateTransformer,
                    noResultsText: noResultsText
                )
        },
            valueToListViewStateTransformer: valueToListViewStateTransformer.showLoadingAndErrorStates()
        )
    }
}

public extension ValueToListViewStateTransformer {
    
    func showLoadingAndErrorStates()
        -> ValueToListViewStateTransformer<Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType> {

            return ValueToListViewStateTransformer
                <Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType>
                { value, state
                    -> ListViewState<Value, P, E, IdiomaticItemModel<ItemModelType>, SectionModelType> in

                    let innerListViewState = self.valueToListViewState(value, state)
                    switch innerListViewState {
                    case let .readyToDisplay(state, sectionsWithItems):
                        return ListViewState.readyToDisplay(
                            state,
                            sectionsWithItems.map { sectionAndItems in
                                return SectionAndItems(
                                    sectionAndItems.section,
                                    sectionAndItems.items.map { IdiomaticItemModel.baseItem($0) }
                                )
                            }
                        )
                    case .notReady:
                        return .notReady
                    }
            }
    }
}

public extension ListViewDatasourceConfiguration {

    typealias ConfigurationWithLoadingAndErrorStates = ListViewDatasourceConfiguration
        <Value, P, E, IdiomaticItemModel<ItemModelType>, ItemView, SectionModelType,
        HeaderItem, HeaderItemView, HeaderItemError, FooterItem, FooterItemView, FooterItemError,
        ContainingView>

    func showLoadingAndErrorStates<ViewProducer: ItemViewProducer>(
        configuration: ShowLoadingAndErrorsConfiguration,
        noResultsText: String,
        loadingViewProducer: ViewProducer,
        errorViewProducer: ViewProducer,
        noResultsViewProducer: ViewProducer
    ) -> ConfigurationWithLoadingAndErrorStates
        where ViewProducer.ItemModelType == IdiomaticItemModel<ItemModelType>,
        ViewProducer.ProducedView == ItemView,
        ViewProducer.ContainingView == ContainingView, ItemModelType.E == E {

            let idiomaticItemModelsProducer = self.itemModelProducer.showLoadingAndErrorStates(
                configuration: configuration,
                noResultsText: noResultsText
            )

            let idiomaticItemViewAdapter = self.itemViewsProducer.showLoadingAndErrorStates(
                configuration: configuration,
                loadingViewProducer: loadingViewProducer,
                errorViewProducer: errorViewProducer,
                noResultsViewProducer: noResultsViewProducer
            )

            let idiomaticDidSelectItem: (ConfigurationWithLoadingAndErrorStates.DidSelectItem)?
            if let didSelectItem = self.didSelectItem {
                idiomaticDidSelectItem = { itemSelection in
                    switch itemSelection.itemModel {
                    case let .baseItem(baseItem):
                        let baseItemSelection = ItemSelection(
                            itemModel: baseItem,
                            view: itemSelection.view,
                            indexPath: itemSelection.indexPath,
                            containingView: itemSelection.containingView
                        )
                        didSelectItem(baseItemSelection)
                    case .loading, .error, .noResults:
                        // Currently, no click handling implemented.
                        break
                    }
                }
            } else {
                idiomaticDidSelectItem = nil
            }

            return ListViewDatasourceConfiguration
                <Value, P, E, IdiomaticItemModel<ItemModelType>, ItemView, SectionModelType,
                HeaderItem, HeaderItemView, HeaderItemError, FooterItem, FooterItemView,
                FooterItemError, ContainingView> (
                    datasource: datasource,
                    itemModelProducer: idiomaticItemModelsProducer,
                    itemViewsProducer: idiomaticItemViewAdapter,
                    headerItemViewAdapter: headerItemViewAdapter,
                    footerItemViewAdapter: footerItemViewAdapter,
                    headerItemAtIndexPath: headerItemAtIndexPath,
                    footerItemAtIndexPath: footerItemAtIndexPath,
                    titleForHeaderInSection: titleForHeaderInSection,
                    titleForFooterInSection: titleForFooterInSection,
                    sectionIndexTitles: sectionIndexTitles,
                    indexPathForIndexTitle: indexPathForIndexTitle,
                    didSelectItem: idiomaticDidSelectItem,
                    willDisplayItem: { itemView, item, indexPath in
                        switch item {
                        case let .baseItem(datasourceItem):
                            self.willDisplayItem?(itemView, datasourceItem, indexPath)
                        case .loading, .error, .noResults:
                            break
                        }
                },
                    willDisplayHeaderItem: willDisplayHeaderItem,
                    willDisplayFooterItem: willDisplayFooterItem
            )
    }
}
