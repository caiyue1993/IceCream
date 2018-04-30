import Foundation
import RealmSwift

public protocol RealmQueueable {
    func appendOperation(_ operation: @escaping (Realm) -> Void)
    func execute(customRealm: Realm?, notificationToken: NotificationToken?)
}

public class RealmQueuer: RealmQueueable {
    let delay: TimeInterval
    var operations: [(Realm) -> Void] = [(Realm) -> Void]()
    fileprivate let throttler: Throttler
    private let realm = try! Realm()

    public init(delay: TimeInterval = 0.5) {
        self.delay = delay
        throttler = Throttler(seconds: delay)
    }

    public func appendOperation(_ operation: @escaping (Realm) -> Void) {
        operations.append(operation)
    }

    public func execute(customRealm: Realm? = nil, notificationToken: NotificationToken?) {
        throttler.throttle { [weak self] in
            guard let `self` = self else { return }
            let definedRealm = customRealm ?? `self`.realm
            /// If your model class includes a primary key, you can have Realm intelligently update or add objects based off of their primary key values using Realm().add(_:update:).
            /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
            definedRealm.beginWrite()
            for op in `self`.operations {
                op(definedRealm)
            }
            if let token = notificationToken {
                try! definedRealm.commitWrite(withoutNotifying: [token])
            } else {
                try! definedRealm.commitWrite()
            }
        }
    }
}

private class Throttler {
    private let queue: DispatchQueue = DispatchQueue.main

    private var job: DispatchWorkItem = DispatchWorkItem(block: {})
    private var previousRun: Date = Date.distantPast
    private var maxInterval: TimeInterval

    init(seconds: TimeInterval) {
        self.maxInterval = seconds
    }

    func throttle(block: @escaping () -> ()) {
        job.cancel()
        job = DispatchWorkItem(){ [weak self] in
            self?.previousRun = Date()
            block()
        }
        let delay = Date().timeIntervalSince(previousRun) > maxInterval ? 0 : maxInterval
        queue.asyncAfter(deadline: .now() + Double(delay), execute: job)
    }
}
