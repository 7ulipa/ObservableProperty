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
    
    public func observeWillDealloc(_ block: @escaping () -> Void) {
        willDealloc.append(Disposable(block))
    }
    
    private var willDealloc: [Disposable] = []
    
    deinit {
        debugPrint("\(self) deinit")
        willDealloc.forEach {
            $0.dispose()
        }
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
    
    @discardableResult public func observeValues(_ block: @escaping (T) -> Void) -> Disposable {
        block(value)
        return observeChanges(block)
    }
    
    
    
    @discardableResult public func observeChanges(_ block: @escaping (T) -> Void) -> Disposable {
        let box = Box((block, self))
        observers.insert(box)
        return Disposable {
            box.value.1.observers.remove(box)
        }
    }
    
    public func map<G>(_ transform: @escaping (T) -> G) -> ObservableProperty<G> {
        let result = ObservableProperty<G>(transform(value))
        result.willDealloc.append(observeChanges { [weak result] (value) in
            result?.value = transform(value)
        })
        return result
    }
    
    public func flatMap<G>(_ transform: @escaping (T) -> ObservableProperty<G>) -> ObservableProperty<G> {
        let mapped = map(transform)
        let result = ObservableProperty<G>(mapped.value.value)
        var currentDispose: Disposable? = mapped.value.observeChanges { [weak result] (value) in
            result?.value = value
        }
        result.willDealloc.append(mapped.observeChanges { [weak result] (value) in
            currentDispose?.dispose()
            currentDispose = value.observeValues { (newValue) in
                result?.value = newValue
            }
        })
        return result
    }
}
