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

final class CatsViewController: UIViewController {
    
    private var cats: [Cat] = []
    private let bag = DisposeBag()
    
    private let realm = try! Realm()
    
    private lazy var addBarItem: UIBarButtonItem = {
        let b = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.add, target: self, action: #selector(add))
        return b
    }()
    
    private lazy var tableView: UITableView = {
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
    
    private func bind() {
        let realm = try! Realm()
        
        /// Results instances are live, auto-updating views into the underlying data, which means results never have to be re-fetched.
        /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
        let cats = realm.objects(Cat.self)
        
        Observable.array(from: cats).subscribe(onNext: { (cats) in
            /// When cats data changes in Realm, the following code will be executed
            /// It works like magic.
            self.cats = cats.filter{ !$0.isDeleted }
            self.tableView.reloadData()
        }).disposed(by: bag)
    }
    
    @objc private func add() {
        let cat = Cat()
        cat.name = "Cat Number " + "\(cats.count)"
        cat.age = cats.count + 1
        
        let data = UIImage(named: cat.age % 2 == 1 ? "heart_cat" : "dull_cat")!.jpegData(compressionQuality: 1.0)
        cat.avatar = CreamAsset.create(object: cat, propName: Cat.AVATAR_KEY, data: data!)
        
        try! realm.write {
            realm.add(cat)
        }
    }
    
}

extension CatsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { (_, ip) in
            let alert = UIAlertController(title: NSLocalizedString("caution", comment: "caution"), message: NSLocalizedString("sure_to_delete", comment: "sure_to_delete"), preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: NSLocalizedString("delete", comment: "delete"), style: .destructive, handler: { (action) in
                guard ip.row < self.cats.count else { return }
                let cat = self.cats[ip.row]
                try! self.realm.write {
                    cat.isDeleted = true
                }
            })
            let defaultAction = UIAlertAction(title: NSLocalizedString("cancel", comment: "cancel"), style: .default, handler: nil)
            alert.addAction(defaultAction)
            alert.addAction(deleteAction)
            self.present(alert, animated: true, completion: nil)
        }
        
        let archiveAction = UITableViewRowAction(style: .normal, title: "Plus") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]
            try! `self`.realm.write {
                cat.age += 1
            }
        }
        let changeImageAction = UITableViewRowAction(style: .normal, title: "Change Img") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]
            try! `self`.realm.write {
                if let imageData = UIImage(named: cat.age % 2 == 0 ? "heart_cat" : "dull_cat")!.jpegData(compressionQuality: 1.0) {
                    cat.avatar = CreamAsset.create(object: cat, propName: Cat.AVATAR_KEY, data: imageData)
                }
            }
        }
        changeImageAction.backgroundColor = .blue
        let emptyImageAction = UITableViewRowAction(style: .normal, title: "Nil Img") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]
            try! `self`.realm.write {
                cat.avatar = nil
            }
        }
        emptyImageAction.backgroundColor = .purple
        return [deleteAction, archiveAction, changeImageAction, emptyImageAction]
    }
}

extension CatsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = cats[indexPath.row].name + " Age: \(cats[indexPath.row].age)"
        if let data = cats[indexPath.row].avatar?.storedData() {
            cell?.imageView?.image = UIImage(data: data)
        } else {
            cell?.imageView?.image = UIImage(named: "cat_placeholder")
        }
        return cell ?? UITableViewCell()
    }
}
