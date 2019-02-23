import Foundation
import UIKit

//open class SimpleCollectionViewDatasource<Value, Item: ListItem, Section: ListSection,
//    SuppItem: SupplementaryItem>: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
//    public typealias Core = ListViewDatasourceCore<Value, Item, UICollectionViewCell, SuppItem,
//    UICollectionReusableView, Section, UICollectionView>
//
//    private let core: Core
//
//    public init(core: Core, collectionView: UICollectionView) {
//        self.core = core
//        registerItemViews(with: collectionView)
//    }
//
//    private func registerItemViews(with collectionView: UICollectionView) {
//        core.itemViewAdapter.registerAtContainingView(collectionView)
//        core.supplementaryItemViewAdapter.registerAtContainingView(collectionView)
//    }
//
//    public func numberOfSections(in collectionView: UICollectionView) -> Int {
//        return core.sections.sectionedValues.sectionsAndValues.count
//    }
//
//    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
//        -> Int {
//        return core.items(in: section).count
//    }
//
//    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
//        -> UICollectionViewCell {
//
//        return core.itemView(at: indexPath, in: collectionView)
//    }
//
//    public func indexTitles(for collectionView: UICollectionView) -> [String]? {
//
//        return core.sectionIndexTitles?()
//    }
//
//    public func collectionView(_ collectionView: UICollectionView,
// viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath)
// -> UICollectionReusableView {
//
//        guard let view = core.supplementaryItemViews(at: indexPath, in: collectionView) else {
//            assert(false, "set ListViewDatasourceCore.supplementaryItemAtIndexPath !")
//            return UICollectionReusableView()
//        }
//
//        return view
//    }
//
//    public func collectionView(_ collectionView: UICollectionView,
// indexPathForIndexTitle title: String, at index: Int) -> IndexPath {
//
//        return core.indexPathForIndexTitle?(title, index) ?? IndexPath()
//    }
//
//}
