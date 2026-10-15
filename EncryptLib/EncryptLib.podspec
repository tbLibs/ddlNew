#
# Be sure to run `pod lib lint EncryptLib.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'EncryptLib'
  s.version          = '0.1.0'
  s.summary          = '文件加密工具类'

  s.description      = <<-DESC
TODO: 封装文件加密算法
                       DESC

  s.homepage         = 'https://github.com/phl/EncryptLib'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'phl' => '244071821@qq.com' }
  s.source           = { :git => 'https://github.com/phl/EncryptLib.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'

  s.source_files = 'EncryptLib/Classes/**/*'
  
  # s.resource_bundles = {
  #   'EncryptLib' => ['EncryptLib/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
