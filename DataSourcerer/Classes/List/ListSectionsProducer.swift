import Foundation

public typealias DefaultSingleSectionListItemsProducer
    <Item: DefaultListItem, Datasource: DatasourceProtocol> =
    DefaultDatasourceStateMapper<SingleSectionListItems<Item>, Datasource>

public typealias DefaultListSectionsProducer
    <Item: DefaultListItem, Section: ListSection, Datasource: DatasourceProtocol> =
    DefaultDatasourceStateMapper<ListSections<Item, Section>, Datasource>
