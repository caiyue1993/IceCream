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

class DogsViewController: UIViewController {
    var notificationToken: NotificationToken? = nil
    
    let jim = Person()
    var dogs:Results<Dog>!
    
    let realm = try! Realm()
    
    lazy var addBarItem: UIBarButtonItem = {
        let b = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.add, target: self, action: #selector(add))
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
        title = "Dogs"
        
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
        dogs = realm.objects(Dog.self)
            .filter("isDeleted = false")
            .sorted(byKeyPath: "id")
        
        notificationToken = dogs.observe({ [weak self] (changes) in
            guard let tableView = self?.tableView else { return }
            
            switch changes {
            case .initial(_):
                tableView.reloadData()
            case .update(_, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                tableView.beginUpdates()
                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}),
                                     with: .automatic)
                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                tableView.endUpdates()
            case .error(let error):
                fatalError("\(error)")
            }
        })
    }
    
    @objc func add() {
        let dog = Dog()
        dog.name = String(format: "Dog %0d", dogs.count + 1)
        dog.owner = jim
        
        let data = UIImage(named: dog.age % 2 == 1 ? "smile_dog" : "tongue_dog")!.pngData()
        dog.avatar = CreamAsset.create(object: dog, propName: Dog.AVATAR_KEY, data: data!)
        try! realm.write {
            realm.add(dog)
        }
    }
    
    deinit {
        notificationToken?.invalidate()
    }
}

extension DogsViewController: UITableViewDelegate {
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
        let changeImageAction = UITableViewRowAction(style: .normal, title: "Change Img") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.dogs.count else { return }
            let dog = `self`.dogs[ip.row]
            try! `self`.realm.write {
                if let imageData = UIImage(named: dog.age % 2 == 0 ? "smile_dog" : "tongue_dog")!.jpegData(compressionQuality: 1.0) {
                  dog.avatar = CreamAsset.create(object: dog, propName: Dog.AVATAR_KEY, data: imageData)
                }
            }
        }
        changeImageAction.backgroundColor = .blue
        let emptyImageAction = UITableViewRowAction(style: .normal, title: "Nil Img") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.dogs.count else { return }
            let dog = `self`.dogs[ip.row]
            try! `self`.realm.write {
                dog.avatar = nil
            }
        }
        emptyImageAction.backgroundColor = .purple
        return [deleteAction, archiveAction, changeImageAction, emptyImageAction]
    }
}

extension DogsViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dogs.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        let price = String(format: "%.2f", dogs[indexPath.row].price.doubleValue)
        cell?.textLabel?.text = dogs[indexPath.row].name + " Age: \(dogs[indexPath.row].age)" + " Price: \(price)" + " id: \(dogs[indexPath.row].id.stringValue)"
        if let data = dogs[indexPath.row].avatar?.storedData() {
            cell?.imageView?.image = UIImage(data: data)
        } else {
            cell?.imageView?.image = UIImage(named: "dog_placeholder")
        }
        return cell ?? UITableViewCell()
    }

}

