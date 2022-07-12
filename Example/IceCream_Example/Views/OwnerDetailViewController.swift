//
//  OwnerDetailViewController.swift
//  IceCream_Example
//
//  Created by Soledad on 2020/9/9.
//  Copyright © 2020 蔡越. All rights reserved.
//

import UIKit
import RealmSwift

final class OwnerDetailViewController: UIViewController {
    
    private var owner: Person? = nil

    private var notificationToken: NotificationToken?
    private let realm = try! Realm()

    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.delegate = self
        tv.dataSource = self
        return tv
    }()
    
    init(owner: Person) {
        self.owner = owner
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        title = "Owner Details"
        
        bind()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.bounds
    }

    private func bind() {
        self.notificationToken = owner!.observe { change in
            switch change {
            case .change, .deleted:
                self.tableView.reloadData()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
}

extension OwnerDetailViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return owner!.cats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = owner!.cats[indexPath.row].name
        if let data = owner!.cats[indexPath.row].avatar?.storedData() {
            cell.imageView?.image = UIImage(data: data)
        } else {
            cell.imageView?.image = UIImage(named: "cat_placeholder")
        }
        return cell
    }
    
}

extension OwnerDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let archiveAction = UITableViewRowAction(style: .normal, title: "Remove") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.owner!.cats.count else { return }
            let owner = `self`.owner!
            try! `self`.realm.write {
                owner.cats.remove(at: ip.row)
            }
        }
        
        return [archiveAction]
    }
}
