import Foundation
import UIKit

//open class SimpleCollectionViewDatasource<Value, Item: ItemModel, Section: SectionModel,
//    SuppItem: SupplementaryItemModel>: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
//    public typealias Configuration = ListViewDatasourceConfiguration<Value, Item, UICollectionViewCell, SuppItem,
//    UICollectionReusableView, Section, UICollectionView>
//
//    private let configuration: Configuration
//
//    public init(configuration: Configuration, collectionView: UICollectionView) {
//        self.configuration = configuration
//        registerItemViews(with: collectionView)
//    }
//
//    private func registerItemViews(with collectionView: UICollectionView) {
//        configuration.itemViewsProducer.registerAtContainingView(collectionView)
//        configuration.supplementaryItemModelViewAdapter.registerAtContainingView(collectionView)
//    }
//
//    public func numberOfSections(in collectionView: UICollectionView) -> Int {
//        return configuration.sections.sectionedValues.sectionsAndValues.count
//    }
//
//    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
//        -> Int {
//        return configuration.items(in: section).count
//    }
//
//    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
//        -> UICollectionViewCell {
//
//        return configuration.itemView(at: indexPath, in: collectionView)
//    }
//
//    public func indexTitles(for collectionView: UICollectionView) -> [String]? {
//
//        return configuration.sectionIndexTitles?()
//    }
//
//    public func collectionView(_ collectionView: UICollectionView,
// viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath)
// -> UICollectionReusableView {
//
//        guard let view = configuration.supplementaryItemModelViews(at: indexPath, in: collectionView) else {
//            assert(false, "set ListViewDatasourceConfiguration.supplementaryItemModelAtIndexPath !")
//            return UICollectionReusableView()
//        }
//
//        return view
//    }
//
//    public func collectionView(_ collectionView: UICollectionView,
// indexPathForIndexTitle title: String, at index: Int) -> IndexPath {
//
//        return configuration.indexPathForIndexTitle?(title, index) ?? IndexPath()
//    }
//
//}
