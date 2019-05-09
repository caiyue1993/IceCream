//
//  BackgroundWorker.swift
//  IceCream
//
//  Created by Kit Forge on 5/9/19.
//

import Foundation
import RealmSwift

// Based on https://academy.realm.io/posts/realm-notifications-on-background-threads-with-swift/
// But extended so it's able to perform multiple blocks.
public class BackgroundWorker: NSObject {
    private var thread: Thread!
    private var block: (() -> Void)!
    var notificationTokens = [NotificationToken]()
    var runLoop: RunLoop!
    
    @objc internal func runBlock() { block() }
    
    override init() {
        super.init()
        
        let threadName = String(describing: self)
            .components(separatedBy: .punctuationCharacters)[1]
        
        thread = Thread { [weak self] in
            self?.runLoop = RunLoop.current
            
            while self != nil && !self!.thread.isCancelled {
                RunLoop.current.run(
                    mode: RunLoop.Mode.default,
                    before: Date.distantFuture)
            }
            Thread.exit()
        }
        thread.name = "\(threadName)-\(UUID().uuidString)"
        thread.start()
    }
    
    public func perform(_ block: @escaping () -> Void) {
        runLoop.perform(block)
    }
    
    public func stop() {
        thread.cancel()
    }
}
