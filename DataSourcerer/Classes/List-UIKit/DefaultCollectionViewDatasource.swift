import Foundation
import UIKit

open class DefaultCollectionViewDatasource
<Datasource: DatasourceProtocol, CellViewProducer: CollectionViewCellProducer, Section: ListSection>
: NSObject, UICollectionViewDataSource, UICollectionViewDelegate
where CellViewProducer.Item : DefaultListItem, CellViewProducer.Item.E == Datasource.E {

    public typealias Core = DefaultListViewDatasourceCore<Datasource, CellViewProducer, Section>

    private let datasource: Datasource
    public var core: Core

    public lazy var sections: AnyStatefulObservable<Core.Sections> = {
        return self.datasource
            .map(self.core.stateToSections)
            .observeOnUIThread()
            .any
    }()

    public init(datasource: Datasource) {
        self.datasource = datasource
        self.core = DefaultListViewDatasourceCore()
    }

    public func configure(with collectionView: UICollectionView, _ build: (Core.Builder) -> (Core.Builder)) {
        core = build(core.builder).core

        core.itemToViewMapping.forEach { args in
            let (itemViewType, producer) = args
            producer.register(itemViewType: itemViewType, at: collectionView)
        }
    }

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.currentValue.value.sectionsWithItems?.count ?? 0
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
        -> Int {
        return sections.currentValue.value.sectionsWithItems?[section].items.count ?? 0
    }

    private func isInBounds(indexPath: IndexPath) -> Bool {
        if let sectionsWithItems = sections.currentValue.value.sectionsWithItems,
            indexPath.section < sectionsWithItems.count,
            indexPath.item < sectionsWithItems[indexPath.section].items.count {
            return true
        } else {
            return false
        }
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
        -> UICollectionViewCell {
        guard let sectionsWithItems = sections.currentValue.value.sectionsWithItems,
            isInBounds(indexPath: indexPath) else {
            print(indexPath)
            print(sections.currentValue.value.sectionsWithItems?.count ?? 0)
            collectionView.register(UICollectionViewCell.self,
                                    forCellWithReuseIdentifier: "noSectionsWithItemsCell")
            return collectionView.dequeueReusableCell(withReuseIdentifier: "noSectionsWithItemsCell",
                                                      for: indexPath)
        }

        let cell = sectionsWithItems[indexPath.section].items[indexPath.item]
        if let itemViewProducer = core.itemToViewMapping[cell.viewType] {
            return itemViewProducer.view(containingView: collectionView, item: cell, for: indexPath)
        } else {
            collectionView.register(UICollectionViewCell.self,
                                    forCellWithReuseIdentifier: "itemToViewMappingMissingCell")
            let fallbackCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "itemToViewMappingMissingCell",
                for: indexPath
            )
            if fallbackCell.viewWithTag(100) == nil {
                let label = UILabel()
                label.tag = 100
                label.text = "Set DefaultListViewDatasourceCore.itemToViewMapping"
                label.textAlignment = .center
                fallbackCell.contentView.addSubview(label)
                label.translatesAutoresizingMaskIntoConstraints = false
                label.topAnchor.constraint(equalTo: fallbackCell.contentView.topAnchor).isActive = true
                label.leftAnchor.constraint(equalTo: fallbackCell.contentView.leftAnchor).isActive = true
                label.rightAnchor.constraint(equalTo: fallbackCell.contentView.rightAnchor).isActive = true
                label.bottomAnchor.constraint(equalTo: fallbackCell.contentView.bottomAnchor).isActive = true
            }
            return fallbackCell
        }
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        guard let sectionsWithItems = sections.currentValue.value.sectionsWithItems,
            isInBounds(indexPath: indexPath) else {
            return
        }
        let sectionWithItems = sectionsWithItems[indexPath.section]
        let cell = sectionWithItems.items[indexPath.item]
        if cell.viewType.isSelectable {
            core.itemSelected?(cell, sectionWithItems.section)
        }
    }

}

public extension DefaultCollectionViewDatasource {

    func sectionWithItems(at indexPath: IndexPath) ->
        SectionWithItems<CellViewProducer.Item, Section>? {
        guard let sectionsWithItems = sections.currentValue.value.sectionsWithItems,
            indexPath.section < sectionsWithItems.count else { return nil }
        return sectionsWithItems[indexPath.section]
    }

    func section(at indexPath: IndexPath) -> Section? {
        return sectionWithItems(at: indexPath)?.section
    }

    func item(at indexPath: IndexPath) -> CellViewProducer.Item? {
        guard let sectionWithItems = self.sectionWithItems(at: indexPath) else { return nil }
        guard indexPath.item < sectionWithItems.items.count else { return nil }
        return sectionWithItems.items[indexPath.item]
    }
}
