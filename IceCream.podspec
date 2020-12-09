#
# Be sure to run `pod lib lint IceCream.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'IceCream'
  s.version          = '10.0.0'
  s.summary          = 'Sync Realm with CloudKit'
  s.description      = <<-DESC
  Sync Realm Database with CloudKit, written in Swift. It works just like magic.
                       DESC
  s.homepage         = 'https://github.com/owenzhao/IceCream'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'caiyue1993' => 'yuecai.nju@gmail.com', 'owenzhao' => 'owenzx@gmail.com' }
  s.source           = { :git => 'https://github.com/owenzhao/IceCream.git', :tag => s.version.to_s }

  s.social_media_url = 'https://twitter.com/caiyue5'

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '3.0'
  s.source_files = ["IceCream/Classes/**/*","IceCream/IceCream.h"]
  s.public_header_files = ["IceCream/IceCream.h"]
  s.static_framework = true
  s.swift_version = '5.0'

  s.dependency 'RealmSwift'
end
