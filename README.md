<p align="center">
	<a href="https://github.com/creativepragmatics/DataSourcerer/"><img src="logo.svg" alt="DataSourcerer—Sending Data to Views without Magic. A Swift library." style="width: 400px;" /></a>
</p>

[![CI Status](https://img.shields.io/travis/creativepragmatics/DataSourcerer.svg?style=flat)](https://travis-ci.org/creativepragmatics/DataSourcerer)
[![Version](https://img.shields.io/cocoapods/v/DataSourcerer.svg?style=flat)](https://cocoapods.org/pods/DataSourcerer)
[![License](https://img.shields.io/cocoapods/l/DataSourcerer.svg?style=flat)](https://cocoapods.org/pods/DataSourcerer)
[![Platform](https://img.shields.io/cocoapods/p/DataSourcerer.svg?style=flat)](https://cocoapods.org/pods/DataSourcerer)

## What is a DataSourcerer?

This Swift library lets you connect an API call (or any other datasource) to the view layer within minutes. It has a ready-to-go `UITableViewDatasource` and `UICollectionViewDatasource` along with matching ViewControllers and is built in a way that datasources for other view types (e.g. `UIStackView`) can be easily composed. 

An idiomatic tableview that displays data from an API call and supports:
* pull-to-refresh, 
* on-disk-caching, 
* clear-view-on-logout,
* a loading indicator if no cached data is shown (e.g. on first app start), 
* displaying "no results" in a dedicated cell if there aren't any, 
* displaying errors in a dedicated cell

can be setup with ~100 lines of code that you have to write (see [Example](Example/DataSourcerer)).

## Usage

The best way to use this library is to create a `Datasource`, and connect it to one or more 
Table/CollectionViewControllers by using the builder pattern provided by  `ListViewDatasourceConfiguration`. 
Features, like showing errors as items/cells, are added in this configuration before creating the actual Table/CollectionViewController.

You can subscribe to changes in the `Datasource` e.g. for stopping the Pull to Refresh indicator after loading is done. 

## How does this work?

DataSourcerer can be viewed as two parts:
1. A very basic [FRP](https://en.wikipedia.org/wiki/Functional_reactive_programming) framework
2. View adapters that subscribe to the FRP framework's structures to do work, like refreshing subviews. The adapters are split into many structs and classes, but Builder patterns added at the crucial points should provide good usability for the most common usage scenarios. 

You may ask, who needs another FRP framework, why reinvent the wheel? There are various reasons this project has its own FRP configuration:
* Reducing references to projects that are not under our control
* Keeping development cadence (e.g. with new Swift releases) independent of other projects
* Avoid binding Datasourcerer users to a specific ReactiveSwift/RxSwift/ReactiveKit/... version (especially annoying for Cocoapods users)
* The self-built approach seems to be easier to debug, because it has way less levels of abstraction due to the reduced feature set.

## Is it tested?

[Yes](Example/Tests). More tests are expected to be added within Q1 2019. The goal is to reach 100% coverage eventually.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

DataSourcerer will __soon__ be available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'DataSourcerer'
```

## Roadmap

Q1 2019:

* Add seamless interaction with various Rx libraries
* Add missing IdiomaticSectionedTableViewDatasource
* Up test coverage to 100%

Later, but ASAP:
* AloeStackView support

## Author

Manuel Maly, manuel@creativepragmatics.com

## License

DataSourcerer is available under the MIT license. See the LICENSE file for more info.
