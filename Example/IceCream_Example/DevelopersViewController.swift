//
//  DevelopersViewController.swift
//  IceCream_Example
//
//  Created by Soledad on 2019/4/13.
//  Copyright © 2019 蔡越. All rights reserved.
//

import UIKit
import RealmSwift
import RxRealm
import RxSwift

class DevelopersViewController: UIViewController {

    var developers: [Person] = []
    let bag = DisposeBag()
    
    let realm = try! Realm()
    
    lazy var addBarItem: UIBarButtonItem = {
        let b = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.add, target: self, action: #selector(add))
        return b
    }()
    
    lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.delegate = self
        tv.dataSource = self
        return tv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        navigationItem.rightBarButtonItem = addBarItem
        title = "Developers"
        
        bind()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.frame
    }
    
    func bind() {
        let realm = try! Realm()
        
        /// Results instances are live, auto-updating views into the underlying data, which means results never have to be re-fetched.
        /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
        let developers = realm.objects(Person.self)
        
        Observable.array(from: developers).subscribe(onNext: { (developers) in
            /// When developers data changes in Realm, the following code will be executed
            /// It works like magic.
            self.developers = developers.filter { !$0.isDeleted }
            self.tableView.reloadData()
        }).disposed(by: bag)
    }
    
    @objc func add() {
        let user = Person()
        user.name = "Yue Cai"
        
        try! realm.write {
            realm.add(user)
        }
    }
}

extension DevelopersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { (_, ip) in
            let alert = UIAlertController(title: NSLocalizedString("caution", comment: "caution"), message: NSLocalizedString("sure_to_delete", comment: "sure_to_delete"), preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: NSLocalizedString("delete", comment: "delete"), style: .destructive, handler: { (action) in
                guard ip.row < self.developers.count else { return }
                let developer = self.developers[ip.row]
                try! self.realm.write {
                    developer.isDeleted = true
                }
            })
            let defaultAction = UIAlertAction(title: NSLocalizedString("cancel", comment: "cancel"), style: .default, handler: nil)
            alert.addAction(defaultAction)
            alert.addAction(deleteAction)
            self.present(alert, animated: true, completion: nil)
        }
        return [deleteAction]
    }
}

extension DevelopersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return developers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = developers[indexPath.row].name
        return cell ?? UITableViewCell()
    }
}
