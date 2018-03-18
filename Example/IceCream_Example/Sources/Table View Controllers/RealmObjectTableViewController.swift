//
//  RealmObjectTableViewController.swift
//  IceCreamExample2
//
//  Created by Andrew Eades on 07/03/2018.
//  Copyright © 2018 Andrew Eades. All rights reserved.
//

import UIKit
import RealmSwift
import IceCream

enum Section: Int {
    case dog = 0
    case cat
}

class RealmObjectTableViewController: UITableViewController {

    var dogs: Results<Dog>?
    var cats: Results<Cat>?

    var dogsNotificationToken: NotificationToken?
    var catsNotificationToken: NotificationToken?
}

extension RealmObjectTableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return numberOfSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfRows(inSection: section)
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */


    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension RealmObjectTableViewController {
    
    var numberOfSections: Int {
        return 2
    }
    
    func numberOfRows(inSection section: Int) -> Int {
        switch section {
        case Section.dog.rawValue:
            return dogs?.count ?? 0
            
        case Section.cat.rawValue:
            return cats?.count ?? 0
            
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell()
        let row = indexPath.row

        let section = indexPath.section
        
        switch section {
        case Section.dog.rawValue:
            if let dog = dogs?[row] {
                cell.textLabel?.text = "\(dog.name) aged \(dog.age)"
                
                if let data = dog.avatar?.storedData() {
                    cell.imageView?.image = UIImage(data: data)
                } else {
                    cell.imageView?.image = UIImage(named: "dog_placeholder")
                }
            }
            
        case Section.cat.rawValue:
            if let cat = cats?[row] {
                cell.textLabel?.text = "\(cat.name) aged \(cat.age)"
            }
        default:
            break
        }
        
        return cell
    }

     // Override to support editing the table view.
     override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            let row = indexPath.row
            let section = indexPath.section

            switch section {
            case Section.dog.rawValue:
                if let dog = dogs?[row] {
                    let realm = try! Realm()
                    try! realm.write {
                        dog.isDeleted = true
                    }
                }
                
            case Section.cat.rawValue:
                if let cat = cats?[row] {
                    let realm = try! Realm()
                    try! realm.write {
                        cat.isDeleted = true
                    }
                }
            default:
                break
            }

        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
     }
    
    func setup() {
        
        let realm = try! Realm()
        
        dogs = realm.objects(Dog.self)
        dogsNotificationToken = dogs?.observe { [weak self] changes in
            guard let tableView = self?.tableView else { return }
            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                tableView.reloadData()
            case .update(_, let deletions, let insertions, let modifications):
                // Query results have changed, so apply them to the UITableView
                tableView.beginUpdates()
                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}),
                                     with: .automatic)
                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                tableView.endUpdates()
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }
        
        cats = realm.objects(Cat.self)
        catsNotificationToken = cats?.observe { [weak self] changes in
            guard let tableView = self?.tableView else { return }
            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                tableView.reloadData()
            case .update(_, let deletions, let insertions, let modifications):
                // Query results have changed, so apply them to the UITableView
                tableView.beginUpdates()
                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 1) }),
                                     with: .automatic)
                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 1)}),
                                     with: .automatic)
                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 1) }),
                                     with: .automatic)
                tableView.endUpdates()
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case Section.dog.rawValue:
            return "Dogs"
            
        case Section.cat.rawValue:
            return "Cats"
        default:
            return ""
        }
    }
    
    override func tableView(_ tableView: UITableView,
                   editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { [weak self] (_, ip) in
            guard let `self` = self else { return }
            
            let section = indexPath.section
            let row = indexPath.row
            let animal: Animal?

            switch section {
            case Section.dog.rawValue:
                animal = `self`.dogs?[row]
                
            default:
                animal = `self`.cats?[row]
            }
            
            let realm = try! Realm()
            try! realm.write {
                animal?.isDeleted = true
            }
        }
        
        let ageAction = UITableViewRowAction(style: .normal, title: "Plus") { [weak self](_, indexPath) in
            guard let `self` = self else { return }
            
            let section = indexPath.section
            let row = indexPath.row
            let animal: Animal?
            
            switch section {
            case Section.dog.rawValue:
                animal = `self`.dogs?[row]
            
            default:
                animal = `self`.cats?[row]
            }
            
            guard animal != nil else { return }
            
            let realm = try! Realm()
            try! realm.write {
                animal?.age += 1
            }
        }
        
        let changeImageAction = UITableViewRowAction(style: .normal, title: "Change Img") { [weak self](_, ip) in
            guard ip.section == Section.dog.rawValue else { return }
            guard let `self` = self else { return }
            guard let dog = `self`.dogs?[ip.row] else { return }
            
            let realm = try! Realm()
            try! realm.write {
                if let imageData = UIImageJPEGRepresentation(UIImage(named: dog.age % 2 == 0 ? "smile_dog" : "tongue_dog")!, 1.0) {
                    dog.avatar = CreamAsset.create(id: dog.id, propName: Dog.AVATAR_KEY, data: imageData)
                }
            }
        }
        changeImageAction.backgroundColor = .blue
        
        let emptyImageAction = UITableViewRowAction(style: .normal, title: "Nil Img") { [weak self](_, ip) in
            guard ip.section == Section.dog.rawValue else { return }
            guard let `self` = self else { return }
            guard let dog = `self`.dogs?[ip.row] else { return }
            let realm = try! Realm()
            try! realm.write {
                dog.avatar = nil
            }
        }
        emptyImageAction.backgroundColor = .purple

        switch indexPath.section {
        case Section.dog.rawValue:
            return [deleteAction, ageAction, changeImageAction, emptyImageAction]

        default:
            return [deleteAction, ageAction]
        }
    }
}
