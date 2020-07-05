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
         viewControllers = [
            UINavigationController(rootViewController: DogsViewController()),
            UINavigationController(rootViewController: CatsViewController()),
            UINavigationController(rootViewController: OwnersViewController())
        ]
    }

}
