#
# Be sure to run `pod lib lint DataSourcerer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DataSourcerer'
  s.version          = '0.2.1'
  s.summary          = 'The missing link between API Calls (any data provider actually) and your UITableView (any view actually).'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
The missing link between API Calls (any data provider actually) and your UITableView (any view actually).
                       DESC

  s.homepage         = 'https://github.com/creativepragmatics/DataSourcerer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Manuel Maly @ Creative Pragmatics' => 'manuel@creativepragmatics.com' }
  s.source           = { :git => 'https://github.com/creativepragmatics/DataSourcerer.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/manuelmaly'

  s.ios.deployment_target = '9.0'

  s.source_files = 'DataSourcerer/Classes/**/*'
  s.swift_version = '4.2'

  s.subspec 'Core' do |ss|
    ss.source_files = 'DataSourcerer/Classes/Core/**/*'
  end

  s.subspec 'List' do |ss|
    ss.source_files = 'DataSourcerer/Classes/List/**/*'
    ss.dependency 'DataSourcerer/Core'
  end

  s.subspec 'List-UIKit' do |ss|
    ss.source_files = 'DataSourcerer/Classes/List-UIKit/**/*'
    ss.dependency 'DataSourcerer/List'
    ss.dependency 'Dwifft', '~> 0.9'
  end

  s.subspec 'Persister-Cache' do |ss|
    ss.source_files = 'DataSourcerer/Classes/Persister-Cache/**/*'
    ss.dependency 'DataSourcerer/Core'
    ss.dependency 'Cache', '~> 5.2.0'
  end

  s.subspec 'ReactiveSwift' do |ss|
    ss.source_files = 'DataSourcerer/Classes/ReactiveSwift/**/*'
    ss.dependency 'DataSourcerer/List'
    ss.dependency 'ReactiveSwift', '~> 4.0'
  end
  
end
