![IceCream](https://i.loli.net/2017/11/18/5a104e5acfea5.png)

[![CI Status](http://img.shields.io/travis/caiyue1993/IceCream.svg?style=flat)](https://travis-ci.org/caiyue1993/IceCream)
[![Version](https://img.shields.io/cocoapods/v/IceCream.svg?style=flat)](http://cocoapods.org/pods/IceCream)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
<a href="https://swift.org/package-manager/"><img src="https://img.shields.io/badge/SPM-supported-DE5C43.svg?style=flat"></a>
[![License](https://img.shields.io/cocoapods/l/IceCream.svg?style=flat)](http://cocoapods.org/pods/IceCream)
[![Platform](https://img.shields.io/cocoapods/p/IceCream.svg?style=flat)](http://cocoapods.org/pods/IceCream)
   
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/caiyue1993/icecream/issues)
<a href="https://twitter.com/caiyue5"><img src="https://img.shields.io/twitter/follow/caiyue5.svg?style=social"></a>

IceCream helps you sync Realm Database with CloudKit.

> It works like magic!

## Features

- Realm Database
    - [x] Off-line First
    - [x] Thread Safety
    - [x] Reactive Programming
    - [x] Optimized for mobile apps
    - [x] Easy when migrating

- Apple CloudKit
    - [x] Automatical Authentication
    - [x] Silent Push 
    - [x] Free with limits(Private database consumes your user's iCloud quota)

- [x] Delta update
- [x] Reachability(Support Long-lived Operation) 
- [x] Powerful Error Handling 
- [x] Sync Automatically
- [x] Multiple object models support
- [x] Public/Private Database support
- [x] Large Data Syncing
- [x] Manually Synchronization is also supported
- [x] Relationship(To-One/To-Many) support
- [x] Available on every Apple platform(iOS/macOS/tvOS/watchOS)
- [x] Support Realm Lists of Natural Types
- [ ] Complete Documentation 

## Prerequisite

1. Be sure to have enrolled in Apple Developer Program
2. Turn on your iCloud in Capabilities and choose `CloudKit`
3. Turn on Background Modes and check `Background fetch` and `Remote notification` 

## Usage

### Basics

1. Prepare your Realm Objects (e.g. Dog, Cat...):

```swift
class Dog: Object {
    @Persisted(primaryKey: true) var id = NSUUID().uuidString
    @Persisted var name = ""
    @Persisted var age = 0
    @Persisted var isDeleted = false

    static let AVATAR_KEY = "avatar"
    @Persisted var avatar: CreamAsset?

    @Persisted var owner: Person? // to-one relationships must be optional
}
```

2. Do stuff like this:

```swift
extension Dog: CKRecordConvertible & CKRecordRecoverable {
    // Leave it blank is all
}
```

Is that easy? Protocol Extensions do this trick.

3. Start the Engine!

```swift
var syncEngine: SyncEngine?
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    ...
    syncEngine = SyncEngine(objects: [
            SyncObject(type: Dog.self),
            SyncObject(type: Cat.self),
            SyncObject(type: Person.self)
        ])
    application.registerForRemoteNotifications()
    ...
}
```

4. Listen for remote notifications

> The sample code in [AppDelegate](Example/IceCream_Example/AppDelegate.swift) will be a good reference.

That's all you need to do! Every time you write to Realm, the SyncEngine will get notified and handle sync stuff!

For more details, clone the project to see the source code.

### Object Deletions

Yep, we highly recommend you use **Soft Deletions**. That's why we add an `isDeleted` property to `CKRecordConvertible` protocol. 

When you want to delete an object, you just need to set its `isDeleted` property to true and the rest of the things are already taken care of.

*You also don't need to worry about cleaning-up things. It has also been considered.*

### How about syncing asset?

Luckily, we have a perfect solution for syncing asset. 
Absolutely, you could also store your image or kind of resource stuff as `Data` type and everything works fine. But Realm has a [16MB limit](https://realm.io/docs/objc/latest/#current-limitations) of data property. And CloudKit encourages us to use `CKAsset` in places where the data you want to assign to a field is more than a few kilobytes in size.
So taking the consideration of the above two, we recommend you to use `CreamAsset` property to hold data. `CreamAsset` will store local data on the file system and just save file paths in the Realm, all automatically. And we'll wrap things up to upload to CloudKit as `CKAsset`. 

An example project is provided to see the detailed usage.

### Relationships 

IceCream has officially supported Realm relationship(both one-to-one and one-to-many) since version 2.0.

Especially, for the support of to-many relationship, you have to pass the element type of the List to the SyncObject init method parameters. For example:
```swift
syncEngine = SyncEngine(objects: [
            SyncObject(type: Dog.self),
            SyncObject(type: Cat.self),
            SyncObject(type: Person.self, uListElementType: Cat.self) // if Person model has a List<Cat> property
        ])
```

## Requirements

- iOS 10.0+ / macOS 10.12+ / tvOS 10.0+ / watchOS 4.0+ 
- Swift 5

## Debug Suggestions

It's true that debugging CloudKit is hard and tedious. But I have some tips for you guys when facing puzzles:

- You should know how Realm and CloudKit works.
- Using GUI tools, like [Realm Browser](https://itunes.apple.com/us/app/realm-browser/id1007457278?mt=12) and [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard).
- When you are lost and don't remember where you are, I suggest starting all over again. In CloudKit Dashboard, "Reset..." button is provided. You can also clear local database by re-install apps.
- By default, IceCream only prints some logs to your console in DEBUG mode. However, you could turn it off by adding `IceCream.shared.enableLogging = false` if it bothers you.
- Keep calm and carry on!

*Warning: If you're going to launch your app onto App Store, don't forget to deploy your environment settings to production. You can do it easily in the CloudKit Dashboard. Write & Read permissions are also need to be considered.*

### One More Tip

How to debug CloudKit in production mode? See this [post](https://stackoverflow.com/questions/30182521/use-production-cloudkit-during-development).

## Example

To run the example project, clone the repo, then open the `Example/IceCream_Example.xcodeproj`.

## Installation Guide

Using Swift Package Manager, Carthage or CocoaPods.

### Swift Package Manager

From Xcode 11, you can use [Swift Package Manager](https://swift.org/package-manager/) to add IceCream and its dependencies to your project.

Select File > Swift Packages > Add Package Dependency. Enter https://github.com/caiyue1993/IceCream.git in the "Choose Package Repository" dialog.
In the next page, specify the version resolving rule as "Up to Next Major" with "2.0.2" as its earliest version.
After Xcode checking out the source and resolving the version, you can choose the "IceCream" library and add it to your app target.

If you encounter any problem or have a question on adding the package to an Xcode project, I suggest reading the [Adding Package Dependencies to Your App](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app) guide article from Apple.

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager for Cocoa applications.

To integrate IceCream into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "caiyue1993/IceCream"
```

Then, run the following command to build the frameworks:

```bash
carthage update
```

Normally, you'll get **IceCream**, **Realm** and **RealmSwift** frameworks. You need to set up your Xcode project manually to add these 3 frameworks.

On your application targets’ **General** settings tab, in the **Linked Frameworks and Libraries** section, drag and drop each framework to use from the `Carthage/Build` folder on disk.

On your application targets’ **Build Phases** settings tab, click the “+” icon and choose “New Run Script Phase”. Create a Run Script with the following content:

```bash
/usr/local/bin/carthage copy-frameworks
```

and add the paths to the frameworks you want to use under “Input Files”(taking iOS platform for example):

```
$(SRCROOT)/Carthage/Build/iOS/IceCream.framework
$(SRCROOT)/Carthage/Build/iOS/Realm.framework
$(SRCROOT)/Carthage/Build/iOS/RealmSwift.framework
```

For more information about how to use Carthage, please see its [project page](https://github.com/Carthage/Carthage).

### CocoaPods

IceCream is available through [CocoaPods](http://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod 'IceCream'
```

> If you want to build IceCream as a static framework, CocoaPods 1.4.0+ is required.

## Make it better

This is the to-do list for the IceCream project. You can join us to become a contributor.

- [ ] CloudKit Shared Database 

See the [CONTRIBUTING](docs/CONTRIBUTING.md) file for contributing guidelines.

## Live Demo

My app [Music Mate](https://apps.apple.com/app/music-mate-for-apple-music/id1605379758) (The missing mate for Apple Music) is using IceCream to its fullest. You can download it and try it on your multiple devices to see this magic.

<a href="https://apps.apple.com/app/music-mate-for-apple-music/id1605379758">
  <img src="https://github.com/caiyue1993/Tiptoes/blob/master/images/appstore.png">
</a>

## Reference

- [Synchronizing data with CloudKit](https://medium.com/@guilhermerambo/synchronizing-data-with-cloudkit-94c6246a3fda) (Recommended)
- [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2016/231/)
- [Mastering Realm Notifications](https://academy.realm.io/posts/meetup-jp-simard-mastering-realm-notifications/)

## Contributors

This project exists thanks to all the people who contribute:

<a href="https://github.com/caiyue1993/IceCream/graphs/contributors"><img src="https://opencollective.com/IceCream/contributors.svg?width=890&button=false" /></a>

## Sponsorship

Open source is great, but it takes time and efforts to maintain. I'd be greatly appreciated and motivated if you could to support the maintenance of IceCream financially. You could sponsor this project through the below ways:

- Become my [GitHub Sponsors](https://github.com/sponsors/caiyue1993), recommended
- Back me on [Open Collective](https://opencollective.com/icecream)
- Transfer your donations directly via [PayPal](https://paypal.me/yuecai)

And thanks to all our backers on open collective:

<a href="https://opencollective.com/icecream#backers" target="_blank"><img src="https://opencollective.com/icecream/backers.svg?width=890"></a>

## License

IceCream is available under the MIT license. See the LICENSE file for more info.
