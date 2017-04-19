//
//  ViewController.swift
//  ObservableProperty
//
//  Created by darwin.jxzang@gmail.com on 04/20/2017.
//  Copyright (c) 2017 darwin.jxzang@gmail.com. All rights reserved.
//

import UIKit
import ObservableProperty

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let property = ObservableProperty(ObservableProperty(1))
        var count = 0
        if #available(iOS 10.0, *) {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak property] (_) in
                if let property = property {
                    let new = ObservableProperty(count)
                    DispatchQueue.global().async { [weak new] in
                        var i = 0
                        while i < 100 {
                            usleep(200000)
                            new?.value = count + 1
                            count = count + 1
                            i = i + 1
                        }
                    }
                    property.value = new
                }
            }
            RunLoop.current.add(timer, forMode: .commonModes)
        }
        
        var c = 0
        let d = property.flatMap { $0 }.observe { (value) in
            debugPrint(c, value)
            c = c + 1
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { 
            d.dispose()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

