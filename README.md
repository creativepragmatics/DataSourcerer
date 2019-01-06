<p align="center">
	<a href="https://github.com/creativepragmatics/DataSourcerer/"><img src="logo.svg" alt="DataSourcerer—Sending Data to Views without Magic. A Swift library." style="width: 400px;" /></a>
</p>

[![CI Status](https://img.shields.io/travis/creativepragmatics/DataSourcerer.svg?style=flat)](https://travis-ci.org/creativepragmatics/DataSourcerer)
[![Version](https://img.shields.io/cocoapods/v/DataSourcerer.svg?style=flat)](https://cocoapods.org/pods/DataSourcerer)
[![License](https://img.shields.io/cocoapods/l/DataSourcerer.svg?style=flat)](https://cocoapods.org/pods/DataSourcerer)
[![Platform](https://img.shields.io/cocoapods/p/DataSourcerer.svg?style=flat)](https://cocoapods.org/pods/DataSourcerer)

# What is a DataSourcerer?

This Swift library lets you connect an API call (or any other datasource) to the view layer within minutes. It has a ready-to-go `UITableViewDatasource` and `UICollectionViewDatasource` along with matching ViewControllers and is built in a way that datasources for other view types (e.g. `UIStackView`) can be easily composed. 

An idiomatic tableview that displays data from an API call and supports:
* pull-to-refresh, 
* on-disk-caching, 
* clear-view-on-logout,
* a loading indicator, 
* a "no results" cell, and 
* an error cell 

can be setup with ~250 lines (see [Example](Example/DataSourcerer)).

# How does this work?

DataSourcerer can be viewed as two parts:
1. A very basic [FRP](https://en.wikipedia.org/wiki/Functional_reactive_programming) core
2. View adapters like a generic [List Datsource Core](DataSourcerer/Classes/List/IdiomaticListViewDatasourceCore.swift) and concrete [idiomatic](DataSourcerer/Classes/List-UIKit/IdiomaticCollectionViewDatasource.swift). [implementations](DataSourcerer/Classes/List-UIKit/IdiomaticSingleSectionListViewDatasourceCore.swift). They use the FRP core's structures 

You may ask, who needs another FRP framework, why reinvent the wheel? There are various reasons this project has its own FRP core:
* Reducing references to projects that are not under our control
* Keeping development cadence (e.g. with new Swift releases) independent of other projects
* Avoid binding Datasourcerer users to a specific ReactiveSwift/RxSwift/ReactiveKit/... version (especially annoying for Cocoapods users)

# Idiomatic

> You keep using that word. I don't think you know what it means.
>
> — Inigo Montoya, The Princess Bride, on Vizzini's use of the word "inconceivable".

Classes whose name starts with `Idiomatic` have behavior encoded that might or might not suit your needs. 

For example: The [IdiomaticCollectionViewDatasource](DataSourcerer/Classes/List-UIKit/IdiomaticCollectionViewDatasource.swift) expects its items to conform to `IdiomaticListItem` which has to implement `loadingCell`, `noResultsCell`, and `errorCell(_)`. Doing so, the CollectionViewDatasource itself is able to decide when it will show the loading state, or a "no results" text, keeping configuration to a minimum. 

If your use case is more complex than that, you will want to implement your own `UICollectionViewDataSource`. You might still be able to use [IdiomaticListViewDatasourceCore](DataSourcerer/Classes/List/IdiomaticListViewDatasourceCore.swift) and profit from the builder pattern implemented there.

The same applies to the [IdiomaticSingleSectionTableViewDatasource](DataSourcerer/Classes/List-UIKit/IdiomaticSingleSectionTableViewDatasource.swift), of course, and other upcoming structures.

# Is it tested?

[Yes](DataSourcerer/tree/master/Example/Tests). More tests are expected to be added within Q1 2019. The goal is to reach 100% coverage eventually.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

DataSourcerer is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'DataSourcerer'
```

## Author

Manuel Maly, manuel@creativepragmatics.com

## License

DataSourcerer is available under the MIT license. See the LICENSE file for more info.
