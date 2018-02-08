//
//  BackgroundWorker.swift
//  IceCream
//
//  Created by Fu Yuan on 7/02/18.
//

import Foundation

class BackgroundWorker: NSObject {
    private var thread: Thread!
    private var block: (()->Void)!
    
    @objc internal func runBlock() { block() }
    
    private func createThread() {
        let threadName = String(describing: self)
            .components(separatedBy: .punctuationCharacters)[1]
        
        thread = Thread { [weak self] in
            while (self != nil && !self!.thread.isCancelled) {
                RunLoop.current.run(
                    mode: RunLoopMode.defaultRunLoopMode,
                    before: Date.distantPast)
            }
            Thread.exit()
        }
        thread.name = "\(threadName)-\(UUID().uuidString)"
        thread.start()
    }
    
    internal func start(_ block: @escaping () -> Void) {
        self.block = block
        
        if thread == nil {
            createThread()
        }
        
        perform(#selector(runBlock),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoopMode.defaultRunLoopMode.rawValue])
    }
    
    public func stop() {
        thread.cancel()
    }
}
