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
        
        let property = ObservableProperty(createProperty())
        if #available(iOS 10.0, *) {
            let timer = Timer(timeInterval: 3, repeats: true) { [weak property] (_) in
                if let property = property {
                    property.value = self.createProperty()
                }
            }
            RunLoop.current.add(timer, forMode: .commonModes)
        }
        
        var c = 0
        let d = property.flatMap { $0 }.observeValues { (value) in
            debugPrint(c, value)
            c = c + 1
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { 
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

