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
    static var catNumber = 1

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
    @IBAction func addDogButtonTapped(_ sender: Any) {
        let dog = Dog(name: "Dog", age: RealmObjectViewController.dogNumber)
        
        RealmObjectViewController.dogNumber += 1
        
        let realm = try! Realm()
        try! realm.write {
            realm.add(dog)
        }
    }
}

extension RealmObjectViewController {
    @IBAction func addCatButtonTapped(_ sender: Any) {
        let cat = Cat(name: "Cat", age: RealmObjectViewController.catNumber)
        
        RealmObjectViewController.catNumber += 1
        
        let realm = try! Realm()
        try! realm.write {
            realm.add(cat)
        }
    }
}
