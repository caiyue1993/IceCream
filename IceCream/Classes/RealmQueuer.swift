import Foundation
import RealmSwift

class RealmQueuer {
    static let shared = RealmQueuer()
    
    let delay: TimeInterval
    var operations: [(Realm) -> Void] = [(Realm) -> Void]()
    fileprivate let throttler: Throttler
    
    init(delay: TimeInterval = 0.5) {
        self.delay = delay
        throttler = Throttler(seconds: delay)
    }
    
    func appendOperation(_ operation: @escaping (Realm) -> Void) {
        operations.append(operation)
    }
    
    func execute(notificationToken: NotificationToken? = nil) {
        throttler.throttle { [weak self] in
            guard let `self` = self else { return }
            /// If your model class includes a primary key, you can have Realm intelligently update or add objects based off of their primary key values using Realm().add(_:update:).
            /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
            let realm = try! Realm()
            realm.beginWrite()
            for op in `self`.operations {
                op(realm)
            }
            if let token = notificationToken {
                try! realm.commitWrite(withoutNotifying: [token])
            } else {
                try! realm.commitWrite()
            }
        }
    }
}

private class Throttler {
    private let queue: DispatchQueue = DispatchQueue.global(qos: .background)
    
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
