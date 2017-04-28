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
        
        let s = createProperty(1)
        let d = s.producer.replayLast.flatMap { _ in self.createProperty(0.1).producer }.observe { (value) in
            debugPrint(value)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            d.dispose()
        }
    }
    
    private func createProperty(_ interval: TimeInterval = 1) -> ObservableProperty<Int> {
        let new = ObservableProperty<Int>(0)
        if #available(iOS 10.0, *) {
            let t = Timer(timeInterval: interval, repeats: true, block: { (_) in
                new.value += 1
            })
            RunLoop.main.add(t, forMode: .commonModes)
            new.willDeinit.append {
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

