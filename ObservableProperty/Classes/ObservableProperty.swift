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
    
    public let producer = Subject<T>(shouldReplayLast: true)
    
    public var willDeinit: [() -> Void] = []
    
    deinit {
        debugPrint("\(self) deinit")
        producer.tearDown()
        willDeinit.forEach { $0() }
    }
    
    public var value: T {
        didSet {
            producer.consume(value)
        }
    }
    
    public init(_ value: T) {
        self.value = value
        producer.consume(value)
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
    fileprivate let shouldReplayLast: Bool
    private var last: Last<T> = .initial
    
    public init(scheduler: Scheduler = .immediate, shouldReplayLast: Bool = false) {
        self.scheduler = scheduler
        self.shouldReplayLast = shouldReplayLast
    }
    
    public func consume(_ value: T) {
        if shouldReplayLast {
            last = .value(value)
        }
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
        if shouldReplayLast, case .value(let value) = last {
            scheduler.schedule {
                observer(value)
            }
        }
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
    
    public var replayLast: Subject {
        if shouldReplayLast {
            return self
        } else {
            let new = Subject(shouldReplayLast: true)
            let d = observe { [weak new] value in
                new?.consume(value)
            }
            new.willDeinit.append {
                d.dispose()
            }
            return new
        }
    }
    
    public func map<G>(transform: @escaping (T) -> G) {
        let new = Subject<G>(shouldReplayLast: shouldReplayLast)
        let d = observe { [weak new] (value) in
            new?.consume(transform(value))
        }
        new.willDeinit.append {
            d.dispose()
        }
    }
    
    public func flatMap<G>(transform: @escaping (T) -> Subject<G>) -> Subject<G> {
        let new = Subject<G>(shouldReplayLast: shouldReplayLast)
        var lastDispose: Disposable?
        let d = observe { [weak new] (value) in
            lastDispose?.dispose()
            lastDispose = transform(value).observe({ (value) in
                new?.consume(value)
            })
        }
        new.willDeinit.append {
            d.dispose()
            lastDispose?.dispose()
        }
        return new
    }
    
    public func combineLatest<G>(with subject: Subject<G>) -> Subject<(T, G)> {
        let new = Subject<(T, G)>(shouldReplayLast: shouldReplayLast)
        var combined = (Last<T>.initial, Last<G>.initial)
        
        let process = { [weak new] in
            if case .value(let value1) = combined.0, case .value(let value2) = combined.1 {
                new?.consume((value1, value2))
            }
        }
        
        let d1 = observe { (value) in
            combined.0 = .value(value)
            process()
        }
        
        let d2 = subject.observe { (value) in
            combined.1 = .value(value)
            process()
        }
        
        new.willDeinit.append {
            d1.dispose()
            d2.dispose()
        }
        
        return new
    }
}

extension Subject where T: Equatable {
    var distinct: Subject {
        let new = Subject(shouldReplayLast: shouldReplayLast)
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

