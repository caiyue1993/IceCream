//
//  CloudKitRecordTableViewController.swift
//  IceCreamExample2
//
//  Created by Andrew Eades on 07/03/2018.
//  Copyright © 2018 Andrew Eades. All rights reserved.
//

import UIKit
import CloudKit
import IceCream

protocol ObjectDescriptionDelegate {
    var objectTypeName: String { get }
    var zoneName: String { get }
    var database: CKDatabase? { get }
    

}

protocol CloudKitRecordTableViewControllerProtocol  {
    var objectDescriptionDelegate: ObjectDescriptionDelegate? { get set }
    var records: [CKRecord] { get set }
}

class CloudKitRecordTableViewController: UITableViewController, CloudKitRecordTableViewControllerProtocol {
    var objectDescriptionDelegate: ObjectDescriptionDelegate? = nil

    var records: [CKRecord] = []
    
}

extension CloudKitRecordTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let zoneName = objectDescriptionDelegate?.zoneName else { return }
        guard let objectTypeName = objectDescriptionDelegate?.objectTypeName else { return }

        let recordZoneID = CKRecordZoneID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        fetchAll(recordType: objectTypeName, recordZoneID: recordZoneID)
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
        return numberOfRows
    }

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
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

extension CloudKitRecordTableViewController {
    var numberOfSections: Int {
        return 1
    }
    
    var numberOfRows: Int {
        return records.count
    }
    
    func setup() {

        startObservingRemoteChanges()
    }
    
     override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
     
        let row = indexPath.row
        let record = records[row]
        if let name = record.value(forKey: "name") as? String {
            cell.textLabel?.text = name
        }
        
        return cell
     }

    private func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, queue: OperationQueue.main, using: { [weak self](_) in
            guard let weakSelf = self else { return }
            guard let zoneName = weakSelf.objectDescriptionDelegate?.zoneName else { return }
            guard let objectTypeName = weakSelf.objectDescriptionDelegate?.objectTypeName else { return }

            let recordZoneID = CKRecordZoneID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

            self?.fetchAll(recordType: objectTypeName, recordZoneID: recordZoneID)
        })
    }
    
    private func fetchAll(recordType: String, recordZoneID: CKRecordZoneID) {
        self.fetchChanges(recordType: recordType, recordZoneID: recordZoneID) { records in
            self.records = records
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    private func fetchChanges(recordType: String, recordZoneID: CKRecordZoneID, fetchCompletionBlock fetchCompletedWith: @escaping ([CKRecord]) -> Void) {
        let predicate = NSPredicate(value: true)
        
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        objectDescriptionDelegate?.database?.perform(query, inZoneWith: recordZoneID) { records, error in
            guard error == nil, let fetchedRecords = records else {
                fetchCompletedWith([])
                return
            }
            
            fetchCompletedWith(fetchedRecords)
        }
    }
}


class PrivateCloudKitRecordTableViewController: CloudKitRecordTableViewController, ObjectDescriptionDelegate {
    var objectTypeName: String = "Dog"
    
    var zoneName: String = "IceCream"
    
    var database: CKDatabase? = CKContainer.default().privateCloudDatabase
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        objectDescriptionDelegate = self
        
        setup()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
}

class PublicCloudKitRecordTableViewController: CloudKitRecordTableViewController, ObjectDescriptionDelegate {
    var objectTypeName: String = "Cat"
    
    var zoneName: String = "_defaultZone"
    
    var database: CKDatabase? = CKContainer.default().publicCloudDatabase
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        objectDescriptionDelegate = self
        
        setup()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
}

