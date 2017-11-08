//
//  ViewController.swift
//  IceCream
//
//  Created by 278060043@qq.com on 10/17/2017.
//  Copyright (c) 2017 278060043@qq.com. All rights reserved.
//

import UIKit
import RealmSwift
import IceCream
import RxRealm
import RxSwift

class ViewController: UIViewController {
    
    var dogs: [Dog] = []
    let bag = DisposeBag()
    
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
        
        bind()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.frame
    }
    
    func bind() {
        let realm = try! Realm()
        let dogs = realm.objects(Dog.self)
        Observable.array(from: dogs).subscribe(onNext: { (dogs) in
            self.dogs = dogs
            self.tableView.reloadData()
        }).disposed(by: bag)
    }
    
    @objc func add() {
        let dog = Dog()
        dog.name = "Rex"
        dog.age = 1
        try! Cream.shared.insertOrUpdate(object: dog)
    }
}

extension ViewController: UITableViewDelegate {
    
}

extension ViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dogs.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = dogs[indexPath.row].name
        cell?.detailTextLabel?.text = "\(dogs[indexPath.row].age)"
        return cell ?? UITableViewCell()
    }

}

