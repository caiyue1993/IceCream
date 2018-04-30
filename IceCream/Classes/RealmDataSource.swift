import Foundation
import RealmSwift

public class RealmDataSource<T:Object> {
    var additions: [T] = [T]()
    var deletions: [String] = [String]()
    var notificationToken: NotificationToken?
    fileprivate let debouncer: Debouncer
    private let realm = try! Realm()

    public init(delay: TimeInterval = 1) {
        self.debouncer = Debouncer(delay: delay)
        debouncer.callback = execute
    }

    public func setNotificationToken(token: NotificationToken?) {
        notificationToken = token
    }

    public func add(object: T) {
        additions.append(object)
        debouncer.call()
    }

    public func delete(key: String) {
        deletions.append(key)
        debouncer.call()
    }

    private func execute() {
        /// If your model class includes a primary key, you can have Realm intelligently update or add objects based off of their primary key values using Realm().add(_:update:).
        /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
        if !realm.isInWriteTransaction {
            realm.beginWrite()
        }
        realm.add(additions, update: true)
        let objectsToDelete = deletions.compactMap(realm.object(ofType: T.self, forPrimaryKey: $0))
        realm.delete(objectsToDelete)
        if realm.isInWriteTransaction {
            if let token = notificationToken {
                try! realm.commitWrite(withoutNotifying: [token])
            } else {
                try! realm.commitWrite()
            }
        }
    }
}

class Debouncer: NSObject {
    var callback: (() -> ())?
    var delay: Double
    weak var timer: Timer?

    init(delay: Double) {
        self.delay = delay
    }

    func call() {
        timer?.invalidate()
        let nextTimer = Timer.scheduledTimer(timeInterval: delay, target: self, selector: #selector(Debouncer.fireNow), userInfo: nil, repeats: false)
        timer = nextTimer
    }

    @objc func fireNow() {
        self.callback?()
    }
}
