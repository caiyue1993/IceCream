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

    var users: [Person] = []
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
        let users = realm.objects(Person.self)
        
        Observable.array(from: users).subscribe(onNext: { (users) in
            /// When cats data changes in Realm, the following code will be executed
            /// It works like magic.
            self.users = users.filter { !$0.isDeleted }
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
    
}

extension DevelopersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = users[indexPath.row].name
        return cell ?? UITableViewCell()
    }
}
