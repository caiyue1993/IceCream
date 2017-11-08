#
# Be sure to run `pod lib lint IceCream.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'IceCream'
  s.version          = '0.1.0'
  s.summary          = 'A short description of IceCream.'
  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC
  s.homepage         = 'https://github.com/caiyue1993/IceCream'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'caiyue1993' => 'yuecai.nju@gmail.com' }
  s.source           = { :git => 'https://github.com/caiyue1993/IceCream.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'
  s.source_files = 'IceCream/Classes/**/*'
  
  # s.resource_bundles = {
  #   'IceCream' => ['IceCream/Assets/*.png']
  # }
  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'RealmSwift'
  s.dependency 'RxRealm'
end
