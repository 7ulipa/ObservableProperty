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
        let property1 = createProperty()
        let property2 = createProperty()
        let d = property1.combineLatest(with: property2).observeValues { (value) in
            debugPrint(value)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { 
            d.dispose()
        }
    }
    
    private func createProperty() -> ObservableProperty<Int> {
            let new = ObservableProperty(0)
        if #available(iOS 10.0, *) {
            let t = Timer(timeInterval: 0.1, repeats: true, block: { [weak new] (_) in
                if let new = new {
                    new.value = new.value + 1
                }
            })
            RunLoop.main.add(t, forMode: .commonModes)
            new.observeWillDealloc {
                t.invalidate()
            }
        }
        
        return new
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

