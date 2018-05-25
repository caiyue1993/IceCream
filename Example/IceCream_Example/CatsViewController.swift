//
//  CatsViewController.swift
//  IceCream_Example
//
//  Created by 蔡越 on 22/05/2018.
//  Copyright © 2018 蔡越. All rights reserved.
//

import UIKit
import RealmSwift
import IceCream
import RxRealm
import RxSwift

class CatsViewController: UIViewController {
    
    var cats: [Cat] = []
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
        title = "Cats"
        
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
        let cats = realm.objects(Cat.self)
        
        Observable.array(from: cats).subscribe(onNext: { (cats) in
            /// When dogs data changes in Realm, the following code will be executed
            /// It works like magic.
            self.cats = cats.filter{ !$0.isDeleted }
            self.tableView.reloadData()
        }).disposed(by: bag)
    }
    
    @objc func add() {
        let cat = Cat()
        cat.name = "Cat Number " + "\(cats.count)"
        cat.age = cats.count + 1
        
        try! realm.write {
            realm.add(cat)
        }
    }
    
}

extension CatsViewController: UITableViewDelegate {
    
}

extension CatsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = cats[indexPath.row].name + " Age: \(cats[indexPath.row].age)"
        return cell ?? UITableViewCell()
    }
}
