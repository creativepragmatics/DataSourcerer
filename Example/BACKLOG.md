# Datasourcerer Backlog

- Most things called "singleSection" can be deleted now?
- Add builder pattern for Datasource? Expose only one method per step.
- Rename State > ListState
- Make Datasource operate only on States?
- Improve or remove StateErrorMessage from APIError (seems clunky) 
- Internationalize error messages
- Find better name for errorMaker
- Add SwiftFormat by Nick Lockwood
- Split Idiomatic* into BaseItem, LoadableItem, FailableItem, EmptyableItem
- Remove Error from ListItem (put into FailableItem?)
- Make initializer for ListCore without headers and footers (NoSupplementaryItem..), make those configurable
- Rename Parameters protocol (a bit opaque for lib users)

