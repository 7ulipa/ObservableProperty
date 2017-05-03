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
    private var blocks: [() -> Void] = []
    
    var disposed = false
    
    public func dispose() {
        if !disposed {
            disposed = true
            blocks.forEach { $0() }
        }
    }
    
    public func add(_ dispose: @escaping () -> Void) {
        blocks.append(dispose)
    }
    
    public func add(_ dispose: Disposable) {
        if disposed {
            dispose.dispose()
        } else {
            blocks.append {
                dispose.dispose()
            }
        }
    }
    
    public init(_ block: @escaping () -> Void) {
        blocks.append(block)
    }
}

public final class ObservableProperty<T> {
    
    public let signal = Subject<T>()
    public lazy var producer: LazySignal<T> = self.createProducer()
    private func createProducer() -> LazySignal<T> {
        return LazySignal<T> { [weak self] (observer, dispose) in
            if let signal = self?.signal, let value = self?.value {
                observer(value)
                dispose.add(signal.observe(observer))
            }
        }
    }
    
    public var willDeinit: [() -> Void] = []
    
    deinit {
        debugPrint("\(self) deinit")
        signal.tearDown()
        willDeinit.forEach { $0() }
    }
    
    public var value: T {
        didSet {
            signal.consume(value)
        }
    }
    
    public init(_ value: T) {
        self.value = value
        signal.consume(value)
    }
}

public protocol Observable {
    associatedtype Value
    func observe(_ observer: @escaping Observer<Value>) -> Disposable
}

public typealias SchedulerBlock = (() -> Void) -> Void

public enum Scheduler {
    case immediate, gcdQueue(DispatchQueue), operationQueue(OperationQueue), custom(SchedulerBlock)
    public func schedule(_ block: @escaping () -> Void) {
        switch self {
        case .immediate:
            block()
        case .operationQueue(let queue):
            queue.addOperation(block)
        case .gcdQueue(let queue):
            queue.async(execute: block)
        case .custom(let scheduleBlock):
            scheduleBlock(block)
        }
    }
}

public typealias Observer<Value> = (Value) -> Void

private enum Last<Value> {
    case initial, value(Value)
}

public final class Subject<T>: Observable {
    
    public typealias Value = T
    
    private let scheduler: Scheduler
    
    private var last: Last<T> = .initial
    
    public init(scheduler: Scheduler = .immediate) {
        self.scheduler = scheduler
    }
    
    public func consume(_ value: T) {
        scheduler.schedule {
            self.observers.forEach { box in
                box.value.0(value)
            }
        }
    }

    private var observers: Set<Box<(Observer<T>, Subject<T>)>> = []
    fileprivate func tearDown() {
        observers = []
    }
    
    @discardableResult public func observe(_ observer: @escaping Observer<T>) -> Disposable {
        let box = Box<(Observer<T>, Subject<T>)>((observer, self))
        observers.insert(box)
        return Disposable { [weak self, weak box] in
            if let box = box, let `self` = self {
                self.observers.remove(box)
            }
        }
    }
    
    public var willDeinit: [() -> Void] = []
    
    deinit {
        debugPrint("\(self)<\(Unmanaged.passUnretained(self).toOpaque())> deinit")
        willDeinit.forEach { $0() }
    }
}

extension Subject where T: Equatable {
    var distinct: Subject {
        let new = Subject()
        var last: Last<T> = .initial
        let d = observe { [weak new] (value) in
            if case .value(let lastValue) = last, lastValue == value {
                return
            }
            last = .value(value)
            new?.consume(value)
        }
        
        new.willDeinit.append {
            d.dispose()
        }
        return new
    }
}


public final class LazySignal<T>: Observable {
    public typealias Value = T
    
    let didObserve: (@escaping Observer<T>, Disposable) -> Void
    
    public init(didObserve: @escaping (@escaping Observer<T>, Disposable) -> Void) {
        self.didObserve = didObserve
    }
    
    @discardableResult public func observe(_ observer: @escaping (T) -> Void) -> Disposable {
        let subject = Subject<T>()
        let dispose = subject.observe(observer)
        didObserve({ (value: T) in subject.consume(value) }, dispose)
        return dispose
    }
    
    deinit {
        debugPrint("\(self) deinit")
    }
}
