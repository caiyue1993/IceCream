![IceCream](https://i.loli.net/2017/11/18/5a104e5acfea5.png)

[![CI Status](http://img.shields.io/travis/caiyue1993/IceCream.svg?style=flat)](https://travis-ci.org/caiyue1993/IceCream)
[![Version](https://img.shields.io/cocoapods/v/IceCream.svg?style=flat)](http://cocoapods.org/pods/IceCream)
[![License](https://img.shields.io/cocoapods/l/IceCream.svg?style=flat)](http://cocoapods.org/pods/IceCream)
[![Platform](https://img.shields.io/cocoapods/p/IceCream.svg?style=flat)](http://cocoapods.org/pods/IceCream)

IceCream helps you sync Realm Database with CloudKit.

## Features

- Realm Database
    - [x] Off-line First
    - [x] Reactive Programming

- Apple CloudKit
    - [x] Automatical Authentication
    - [x] Data Deletion
    - [x] Reachability(Support Long-lived Operation) 
    - [x] Error Handling
- [] Complete Documentation 

## Prerequisite
1. Be sure to enroll in Apple Developer Program

2. Navigate to project settings

3. Turn on your iCloud in Capabilities and choose `CloudKit`

4. Turn on Background Modes and check `Background fetch` and `Remote notification` 

## Usage
1. Prepare your Realm Object
```swift
class Dog: Object {
    @objc dynamic var id = NSUUID().uuidString
    @objc dynamic var name = ""
    @objc dynamic var age = 0
    
    override class func primaryKey() -> String? {
        return "id"
    }
}
```

2. Make your Realm Object conform to CKRecordConvertible and CKRecordRecoverable 
```swift
extension Dog: CKRecordConvertible {
    /// recordName : this is the unique identifier for the record, used to locate records on the database. We can create our own ID or leave it to CloudKit to generate a random UUID.
    /// For more: https://medium.com/@guilhermerambo/synchronizing-data-with-cloudkit-94c6246a3fda
    var recordID: CKRecordID {
        return CKRecordID(recordName: id, zoneID: Constants.customZoneID)
    }
    
    var record: CKRecord {
        // Simultaneously init CKRecord with zoneID and recordID, thanks to this guy: https://stackoverflow.com/questions/45429133/how-to-initialize-ckrecord-with-both-zoneid-and-recordid
        let r = CKRecord(recordType: Dog.recordType, recordID: recordID)
        r[.id] = id as CKRecordValue
        r[.age] = age as CKRecordValue
        r[.name] = name as CKRecordValue
        return r
    }
    
    static var recordType: String {
        return "Dog"
    }
}

extension Dog: CKRecordRecoverable {
    static func objectFrom(record: CKRecord) -> Object? {
        guard let id = record[.id] as? String,
            let age = record[.age] as? Int,
            let name = record[.name] as? String
            else { return nil }
        
        let dog = Dog()
        dog.id = id
        dog.age = age
        dog.name = name
        
        return dog
    }
}
```

3. Start the Engine!
```swift
var syncEngine: SyncEngine<Dog>?
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    ...
    syncEngine = SyncEngine<Dog>()
    application.registerForRemoteNotifications()
    ...
}
```

For more, clone the example project and run it yourself.

### Deletions
Talk about deletions.

## Requirements

- iOS 10.0+
- Swift 4

## Suggestions

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

IceCream is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'IceCream'
```

## Make it better
1. Fork this project
2. Do your changes
3. Feel free to submit a pull request

## Live Demo
To be added.

## Donation
Crypto currency donation is the best. Even 0.01 BTC helps😄.
### Bitcoin

![BTC Deposit](https://i.loli.net/2017/11/19/5a11078c118b3.png)

14J7KCR2x1Csh52SpPAvMWRh9EyNX5kxhE

### Lisk
Lisk is my preferred crypto currency.

Lisk Deposit Address: 10081270051711082114L

## Reference
- [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2016/231/)
- [Synchronizing data with CloudKit](https://medium.com/@guilhermerambo/synchronizing-data-with-cloudkit-94c6246a3fda)

## License
IceCream is available under the MIT license. See the LICENSE file for more info.
