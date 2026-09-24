#
# Be sure to run `pod lib lint NetWorkStatus.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'NetworkStatus'
  s.version          = '1.0.0'
  s.summary          = '网络状态监听'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: 用于网络状态监听
                       DESC

  s.homepage         = 'https://github.com/Bytes(海亮)/NetWorkStatus'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Bytes(海亮)' => '244071821@qq.com' }
  s.source           = { :git => 'https://github.com/Bytes(海亮)/NetWorkStatus.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'

  s.source_files = 'NetWorkStatus/Classes/**/*'
  
  # s.resource_bundles = {
  #   'NetWorkStatus' => ['NetWorkStatus/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
