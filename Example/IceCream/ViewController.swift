//
//  ViewController.swift
//  IceCream
//
//  Created by 278060043@qq.com on 10/17/2017.
//  Copyright (c) 2017 278060043@qq.com. All rights reserved.
//

import UIKit
import RealmSwift

class ViewController: UIViewController {
    
    var dogs: [Dog] = []
    
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
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.frame
    }
    
    @objc func add() {
        let dog = Dog()
        dog.name = "Rex"
        dog.age = 1
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

