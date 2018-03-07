//
//  RealmObjectViewController.swift
//  IceCreamExample2
//
//  Created by Andrew Eades on 07/03/2018.
//  Copyright © 2018 Andrew Eades. All rights reserved.
//

import UIKit
import RealmSwift

class RealmObjectViewController: UIViewController {
    static var dogNumber = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension RealmObjectViewController {
    @IBAction func addButtonTapped(_ sender: Any) {
        let dog = Dog()
        let leaving4 = dog.id.count - 4
        let dogName = "Dog \(dog.id.dropLast(leaving4))"
        dog.name = dogName
        dog.age = RealmObjectViewController.dogNumber
        
        RealmObjectViewController.dogNumber += 1
        
        let realm = try! Realm()
        try! realm.write {
            realm.add(dog)
        }
    }
}
