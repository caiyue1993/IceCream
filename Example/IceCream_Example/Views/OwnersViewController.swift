//
//  DevelopersViewController.swift
//  IceCream_Example
//
//  Created by Soledad on 2019/4/13.
//  Copyright © 2019 蔡越. All rights reserved.
//

import UIKit
import RealmSwift
import IceCream

final class OwnersViewController: UIViewController {

    var owners: [Person] = []
    
    private var notificationToken: NotificationToken?
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
        let owners = realm.objects(Person.self)
        
        self.notificationToken = owners.observe { (changes: RealmCollectionChange) in
            switch changes {
            case .initial, .update:
                self.owners = owners.filter { !$0.isDeleted }
                self.tableView.reloadData()
            case .error(let err):
                fatalError("\(err)")
            }
        }
    }
    
    @objc private func add() {
        let user = Person()
        user.name = "Yue Cai"
        
        try! realm.write {
            realm.add(user)
        }
    }
}

extension OwnersViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < owners.count else { return }
        let owner = owners[indexPath.row]
        let viewController = OwnerDetailViewController(owner: owner)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let addCatAction = UITableViewRowAction(style: .default, title: "Add cat") { (_, ip) in
            guard ip.row < self.owners.count else { return }
            let owner = self.owners[ip.row]
            let newCat = Cat()
            newCat.name = "\(owner.name)'s No.\(owner.cats.count + 1) cat"
            newCat.age = ip.row
            try! self.realm.write {
                owner.cats.append(newCat)
            }
        }
        let deleteCatAction = UITableViewRowAction(style: .default, title: "Delete cat") { (_, ip) in
            guard ip.row < self.owners.count else { return }
            let owner = self.owners[ip.row]
            try! self.realm.write {
                owner.cats.last?.isDeleted = true
            }
        }
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { (_, ip) in
            let alert = UIAlertController(title: NSLocalizedString("caution", comment: "caution"), message: NSLocalizedString("sure_to_delete", comment: "sure_to_delete"), preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: NSLocalizedString("delete", comment: "delete"), style: .destructive, handler: { (action) in
                guard ip.row < self.owners.count else { return }
                let owner = self.owners[ip.row]
                try! self.realm.write {
                    owner.isDeleted = true
                }
            })
            let defaultAction = UIAlertAction(title: NSLocalizedString("cancel", comment: "cancel"), style: .default, handler: nil)
            alert.addAction(defaultAction)
            alert.addAction(deleteAction)
            self.present(alert, animated: true, completion: nil)
        }
        return [addCatAction, deleteCatAction, deleteAction]
    }
}

extension OwnersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return owners.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = owners[indexPath.row].name
        return cell ?? UITableViewCell()
    }
}
