//
//  ViewController.swift
//  IceCream
//
//  Created by 蔡越 on 10/17/2017.
//  Copyright (c) 2017 Nanjing University. All rights reserved.
//

import UIKit
import RealmSwift
import IceCream
import RxRealm
import RxSwift

class ViewController: UIViewController {
    
    var dogs: [Dog] = []
    let bag = DisposeBag()
    
    let realm = try! Realm()
    
    lazy var addBarItem: UIBarButtonItem = {
        let b = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.add, target: self, action: #selector(add))
        return b
    }()
    lazy var deleteAllBarItem: UIBarButtonItem = {
        let b = UIBarButtonItem(title: "Delete All", style: .plain, target: self, action: #selector(deleteBtn))
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
        navigationItem.leftBarButtonItem = deleteAllBarItem
        
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
        let dogs = realm.objects(Dog.self)
        
        Observable.array(from: dogs).subscribe(onNext: { (dogs) in
            /// When dogs data changes in Realm, the following code will be executed
            /// It works like magic.
            self.dogs = dogs.filter{ !$0.isDeleted }
            self.tableView.reloadData()
        }).disposed(by: bag)
    }
    
    var isOdd: Bool = false
    @objc func add() {
        let dog = Dog()
        dog.name = "Dog Number " + "\(dogs.count)"
        dog.age = dogs.count + 1
        dog.avatar = CreamAsset()
        dog.avatar?.doData(id: dog.id, data: UIImageJPEGRepresentation(UIImage(named: `self`.isOdd ? "Face1" : "Face2")!, 1.0) as Data!)
        isOdd = !isOdd
        
        try! realm.write {
            realm.add(dog)
        }
    }
    @objc func deleteBtn() {
        for dog in dogs {
            try! self.realm.write {
                dog.isDeleted = true
            }
        }
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { (_, ip) in
            let alert = UIAlertController(title: NSLocalizedString("caution", comment: "caution"), message: NSLocalizedString("sure_to_delete", comment: "sure_to_delete"), preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: NSLocalizedString("delete", comment: "delete"), style: .destructive, handler: { (action) in
                guard ip.row < self.dogs.count else { return }
                let dog = self.dogs[ip.row]
                try! self.realm.write {
                    dog.isDeleted = true
                }
            })
            let defaultAction = UIAlertAction(title: NSLocalizedString("cancel", comment: "cancel"), style: .default, handler: nil)
            alert.addAction(defaultAction)
            alert.addAction(deleteAction)
            self.present(alert, animated: true, completion: nil)
        }
        
        let archiveAction = UITableViewRowAction(style: .normal, title: "Plus") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.dogs.count else { return }
            let dog = `self`.dogs[ip.row]
            try! `self`.realm.write {
                dog.age += 1
            }
        }
        let changeImageAction = UITableViewRowAction(style: .normal, title: "Image") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.dogs.count else { return }
            let dog = `self`.dogs[ip.row]
            try! `self`.realm.write {
                dog.avatar?.doData(id: dog.id, data: UIImageJPEGRepresentation(UIImage(named: `self`.isOdd ? "Face1" : "Face2")!, 1.0) as Data!)
                `self`.isOdd = !`self`.isOdd
            }
        }
        return [deleteAction, archiveAction, changeImageAction]
    }
}

extension ViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dogs.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = dogs[indexPath.row].name + "Age: \(dogs[indexPath.row].age)"
        if let path = dogs[indexPath.row].avatar?.path {// not good
            if let data = dogs[indexPath.row].avatar?.fetchData() {
                cell?.imageView?.image = UIImage(data: data)
            } else {
                let path = CreamAsset.diskCachePath(fileName: path)
                let data = NSData(contentsOfFile: path) as Data?
                if let data = data {
                    cell?.imageView?.image = UIImage(data: data)
                }
            }
        }
        return cell ?? UITableViewCell()
    }

}

