//
//  TabBarViewController.swift
//  IceCream_Example
//
//  Created by 蔡越 on 22/05/2018.
//  Copyright © 2018 蔡越. All rights reserved.
//

import UIKit

final class TabBarViewController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let dogsViewController = DogsViewController()
        dogsViewController.title = "Dogs"
        let catsViewController = CatsViewController()
        catsViewController.title = "Cats"
        let ownersViewController = OwnersViewController()
        ownersViewController.title = "Owners"
        
        viewControllers = [
            UINavigationController(rootViewController: dogsViewController),
            UINavigationController(rootViewController: catsViewController),
            UINavigationController(rootViewController: ownersViewController)
        ]
    }

}
