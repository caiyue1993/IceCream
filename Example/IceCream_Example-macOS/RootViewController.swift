//
//  RootViewController.swift
//  IceCream_Example-macOS
//
//  Created by Soledad on 2019/8/10.
//  Copyright © 2019 蔡越. All rights reserved.
//

import AppKit
import RxCocoa
import RxSwift
import Realm
import RealmSwift
import RxRealm

class RootViewController: NSViewController {
    
    var dogs: [Dog] = []
    let bag = DisposeBag()
    
    @IBOutlet weak var tableView: NSTableView!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bind()
    }
    
    private func bind() {
        let realm = try! Realm()
        let dogs = realm.objects(Dog.self)
        
        Observable.array(from: dogs).subscribe(onNext: { (dogs) in
            self.dogs = dogs.filter { !$0.isDeleted }
            self.tableView.reloadData()
        }).disposed(by: bag)
    }
    
}

extension RootViewController: NSTableViewDelegate {
    
}

extension RootViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return dogs.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cell: NSTableCellView? = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("cell"), owner: tableView) as? NSTableCellView
        cell?.textField?.stringValue = dogs[row].name
        
        return cell
    }
}
