import Foundation

public protocol ItemModel: Equatable {
    associatedtype E: ResourceError

    // Required to display configuration or system errors
    // for easier debugging.
    init(error: E)
}

public struct SectionAndItems<Item: ItemModel, Section: SectionModel>: Equatable {
    public let section: Section
    public let items: [Item]

    public init(_ section: Section, _ items: [Item]) {
        self.section = section
        self.items = items
    }
}
