//
//  ObservableProperty.swift
//  Pods
//
//  Created by DirGoTii on 20/04/2017.
//
//

import Foundation

final class Box<T>: Hashable {
    let value: T
    init(_ value: T) {
        self.value = value
    }
    var hashValue: Int {
        return Unmanaged.passUnretained(self).toOpaque().hashValue
    }
}

func ==<T>(l: Box<T>, r: Box<T>) -> Bool {
    return l === r
}

public final class Disposable {
    private let block: () -> Void
    
    public func dispose() {
        block()
    }
    
    public init(_ block: @escaping () -> Void) {
        self.block = block
    }
}

public final class ObservableProperty<T> {
    
    private var deinitDiseposable: Disposable?
    
    deinit {
        debugPrint("\(self) deinit")
        deinitDiseposable?.dispose()
    }
    
    private var observers: Set<Box<((T) -> Void, ObservableProperty<T>)>> = []
    
    public var value: T {
        didSet {
            observers.forEach { (box) in
                box.value.0(value)
            }
        }
    }
    
    public init(_ value: T) {
        self.value = value
    }
    
    @discardableResult public func observe(_ block: @escaping (T) -> Void) -> Disposable {
        block(value)
        let box = Box((block, self))
        observers.insert(box)
        return Disposable { 
            box.value.1.observers.remove(box)
        }
    }
    
    public func map<G>(_ transform: @escaping (T) -> G) -> ObservableProperty<G> {
        let result = ObservableProperty<G>(transform(value))
        result.deinitDiseposable = observe { [weak result] (value) in
            result?.value = transform(value)
        }
        return result
    }
    
    public func flatMap<G>(_ transform: @escaping (T) -> ObservableProperty<G>) -> ObservableProperty<G> {
        let mapped = map(transform)
        var currentDispose: Disposable?
        let result = ObservableProperty<G>(mapped.value.value)
        result.deinitDiseposable = mapped.observe { [weak result] (value) in
            currentDispose?.dispose()
            currentDispose = value.observe { (newValue) in
                result?.value = newValue
            }
        }
        return result
    }
}
