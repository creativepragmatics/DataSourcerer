#if os(iOS) || os(tvOS)
import DifferenceKit
import UIKit

extension UITableView: SourcererExtensionsProvider {}

extension SourcererExtension where Base: UITableView {
    /// Applies multiple animated updates in stages using `StagedChangeset`.
    ///
    /// - Note: There are combination of changes that crash when applied simultaneously in `performBatchUpdates`.
    ///         Assumes that `StagedChangeset` has a minimum staged changesets to avoid it.
    ///         The data of the data-source needs to be updated synchronously before `performBatchUpdates` in every stages.
    ///
    /// - Parameters:
    ///   - stagedChangeset: A staged set of changes.
    ///   - animation: An option to animate the updates.
    ///   - interrupt: A closure that takes an changeset as its argument and returns `true` if the animated
    ///                updates should be stopped and performed reloadData. Default is nil.
    ///   - setData: A closure that takes the collection as a parameter.
    ///              The collection should be set to data-source of UITableView.
    func reload<C>(
        using stagedChangeset: StagedChangeset<C>,
        with animation: @autoclosure () -> UITableView.RowAnimation,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        updateCell: (IndexPath, UITableView) -> TableViewCellUpdateMode, // IndexPath is from before the updates
        setData: (C) -> Void
        ) {
        reload(
            using: stagedChangeset,
            deleteSectionsAnimation: animation(),
            insertSectionsAnimation: animation(),
            reloadSectionsAnimation: animation(),
            deleteRowsAnimation: animation(),
            insertRowsAnimation: animation(),
            reloadRowsAnimation: animation(),
            interrupt: interrupt,
            updateCell: updateCell,
            setData: setData
        )
    }

    /// Applies multiple animated updates in stages using `StagedChangeset`.
    ///
    /// - Note: There are combination of changes that crash when applied simultaneously in `performBatchUpdates`.
    ///         Assumes that `StagedChangeset` has a minimum staged changesets to avoid it.
    ///         The data of the data-source needs to be updated synchronously before `performBatchUpdates` in every stages.
    ///
    /// - Parameters:
    ///   - stagedChangeset: A staged set of changes.
    ///   - deleteSectionsAnimation: An option to animate the section deletion.
    ///   - insertSectionsAnimation: An option to animate the section insertion.
    ///   - reloadSectionsAnimation: An option to animate the section reload.
    ///   - deleteRowsAnimation: An option to animate the row deletion.
    ///   - insertRowsAnimation: An option to animate the row insertion.
    ///   - reloadRowsAnimation: An option to animate the row reload.
    ///   - interrupt: A closure that takes an changeset as its argument and returns `true` if the animated
    ///                updates should be stopped and performed reloadData. Default is nil.
    ///   - setData: A closure that takes the collection as a parameter.
    ///              The collection should be set to data-source of UITableView.
    // swiftlint:disable:next function_parameter_count
    func reload<C>(
        using stagedChangeset: StagedChangeset<C>,
        deleteSectionsAnimation: @autoclosure () -> UITableView.RowAnimation,
        insertSectionsAnimation: @autoclosure () -> UITableView.RowAnimation,
        reloadSectionsAnimation: @autoclosure () -> UITableView.RowAnimation,
        deleteRowsAnimation: @autoclosure () -> UITableView.RowAnimation,
        insertRowsAnimation: @autoclosure () -> UITableView.RowAnimation,
        reloadRowsAnimation: @autoclosure () -> UITableView.RowAnimation,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        updateCell: (IndexPath, UITableView) -> TableViewCellUpdateMode,
        setData: (C) -> Void
    ) {
        if case .none = base.window, let data = stagedChangeset.last?.data {
            setData(data)
            return base.reloadData()
        }

        for changeset in stagedChangeset {
            if let interrupt = interrupt, interrupt(changeset), let data = stagedChangeset.last?.data {
                setData(data)
                return base.reloadData()
            }

            _performBatchUpdates {
                setData(changeset.data)

                if !changeset.sectionDeleted.isEmpty {
                    base.deleteSections(IndexSet(changeset.sectionDeleted), with: deleteSectionsAnimation())
                }

                if !changeset.sectionInserted.isEmpty {
                    base.insertSections(IndexSet(changeset.sectionInserted), with: insertSectionsAnimation())
                }

                if !changeset.sectionUpdated.isEmpty {
                    base.reloadSections(IndexSet(changeset.sectionUpdated), with: reloadSectionsAnimation())
                }

                for (source, target) in changeset.sectionMoved {
                    base.moveSection(source, toSection: target)
                }

                if !changeset.elementDeleted.isEmpty {
                    base.deleteRows(at: changeset.elementDeleted.map { IndexPath(row: $0.element, section: $0.section) }, with: deleteRowsAnimation())
                }

                if !changeset.elementInserted.isEmpty {
                    base.insertRows(at: changeset.elementInserted.map { IndexPath(row: $0.element, section: $0.section) }, with: insertRowsAnimation())
                }

                if !changeset.elementUpdated.isEmpty {
                    let indexPaths = changeset.elementUpdated.map { IndexPath(row: $0.element, section: $0.section) }
                    let rowsToReload = indexPaths.filter { indexPath in
                        switch updateCell(indexPath, base) {
                        case .reload:
                            return true
                        case .reconfigure(let execute):
                            guard let cell = base.cellForRow(at: indexPath) else { return false }
                            execute(cell)
                            return false
                        }
                    }
                    base.reloadRows(at: rowsToReload, with: reloadRowsAnimation())
                }

                for (source, target) in changeset.elementMoved {
                    base.moveRow(at: IndexPath(row: source.element, section: source.section), to: IndexPath(row: target.element, section: target.section))
                }
            }
        }
    }

    private func _performBatchUpdates(_ updates: () -> Void) {
        if #available(iOS 11.0, tvOS 11.0, *) {
            base.performBatchUpdates(updates)
        }
        else {
            base.beginUpdates()
            updates()
            base.endUpdates()
        }
    }
}

public extension UICollectionView {
    /// Applies multiple animated updates in stages using `StagedChangeset`.
    ///
    /// - Note: There are combination of changes that crash when applied simultaneously in `performBatchUpdates`.
    ///         Assumes that `StagedChangeset` has a minimum staged changesets to avoid it.
    ///         The data of the data-source needs to be updated synchronously before `performBatchUpdates` in every stages.
    ///
    /// - Parameters:
    ///   - stagedChangeset: A staged set of changes.
    ///   - interrupt: A closure that takes an changeset as its argument and returns `true` if the animated
    ///                updates should be stopped and performed reloadData. Default is nil.
    ///   - setData: A closure that takes the collection as a parameter.
    ///              The collection should be set to data-source of UICollectionView.
    func reload<C>(
        using stagedChangeset: StagedChangeset<C>,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        setData: (C) -> Void
    ) {
        if case .none = window, let data = stagedChangeset.last?.data {
            setData(data)
            return reloadData()
        }

        for changeset in stagedChangeset {
            if let interrupt = interrupt, interrupt(changeset), let data = stagedChangeset.last?.data {
                setData(data)
                return reloadData()
            }

            performBatchUpdates({
                setData(changeset.data)

                if !changeset.sectionDeleted.isEmpty {
                    deleteSections(IndexSet(changeset.sectionDeleted))
                }

                if !changeset.sectionInserted.isEmpty {
                    insertSections(IndexSet(changeset.sectionInserted))
                }

                if !changeset.sectionUpdated.isEmpty {
                    reloadSections(IndexSet(changeset.sectionUpdated))
                }

                for (source, target) in changeset.sectionMoved {
                    moveSection(source, toSection: target)
                }

                if !changeset.elementDeleted.isEmpty {
                    deleteItems(at: changeset.elementDeleted.map { IndexPath(item: $0.element, section: $0.section) })
                }

                if !changeset.elementInserted.isEmpty {
                    insertItems(at: changeset.elementInserted.map { IndexPath(item: $0.element, section: $0.section) })
                }

                if !changeset.elementUpdated.isEmpty {
                    reloadItems(at: changeset.elementUpdated.map { IndexPath(item: $0.element, section: $0.section) })
                }

                for (source, target) in changeset.elementMoved {
                    moveItem(at: IndexPath(item: source.element, section: source.section), to: IndexPath(item: target.element, section: target.section))
                }
            })
        }
    }
}
#endif

enum TableViewCellUpdateMode {
    case reload
    case reconfigure(execute: (UITableViewCell) -> Void) // doesn't reload, but only resets the cell's data
}
