//
//  OwnerDetailViewController.swift
//  IceCream_Example
//
//  Created by Soledad on 2020/9/9.
//  Copyright © 2020 蔡越. All rights reserved.
//

import UIKit

final class OwnerDetailViewController: UIViewController {

    private let cats: [Cat]
    
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.dataSource = self
        return tv
    }()
    
    init(cats: [Cat]) {
        self.cats = cats
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        title = "OwnerDetailViewController"
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.bounds
    }
    
}

extension OwnerDetailViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = cats[indexPath.row].name
        if let data = cats[indexPath.row].avatar?.storedData() {
            cell.imageView?.image = UIImage(data: data)
        } else {
            cell.imageView?.image = UIImage(named: "cat_placeholder")
        }
        return cell
    }
    
}
