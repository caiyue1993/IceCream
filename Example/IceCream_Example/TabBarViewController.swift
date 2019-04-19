//
//  TabBarViewController.swift
//  IceCream_Example
//
//  Created by 蔡越 on 22/05/2018.
//  Copyright © 2018 蔡越. All rights reserved.
//

import UIKit

class TabBarViewController: UITabBarController {
    
    lazy var dogsViewController: UIViewController = {
        let nav = UINavigationController(rootViewController: DogsViewController())
        return nav
    }()
    
    lazy var catsViewController: UIViewController = {
        let nav = UINavigationController(rootViewController: CatsViewController())
        return nav
    }()
    
    lazy var usersViewController: UIViewController = {
        let nav = UINavigationController(rootViewController: DevelopersViewController())
        return nav
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        viewControllers = [dogsViewController, catsViewController, usersViewController]
    }

}
