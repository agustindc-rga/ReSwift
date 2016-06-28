//
//  StoreTests.swift
//  ReSwift
//
//  Created by Benjamin Encz on 11/27/15.
//  Copyright © 2015 DigiTales. All rights reserved.
//

import XCTest
@testable import ReSwift

// swiftlint:disable file_length
class StoreTests: XCTestCase {

    func testInit() {
        // Dispatches an Init action when it doesn't receive an initial state

        let reducer = MockReducer()
        let _ = Store<CounterState>(reducer: reducer, state: nil)

        XCTAssert(reducer.calledWithAction[0] is ReSwiftInit)
    }

    func testDeinit() {
        // Deinitializes when no reference is held

        var deInitCount = 0

        autoreleasepool {
            let reducer = TestReducer()
            let _ = DeInitStore(
                reducer: reducer,
                state: TestAppState(),
                deInitAction: { deInitCount += 1 })
        }

        XCTAssertEqual(deInitCount, 1)
    }

}


class StoreSubscribeTest: XCTestCase {

    typealias TestSubscriber = TestStoreSubscriber<TestAppState>

    var store: Store<TestAppState>!
    var reducer: TestReducer!

    override func setUp() {
        super.setUp()
        reducer = TestReducer()
        store = Store(reducer: reducer, state: TestAppState())
    }

    func testStrongCapture() {
        // It does not strongly capture an observer

        store = Store(reducer: reducer, state: TestAppState())
        var subscriber: TestSubscriber? = TestSubscriber()

        #if swift(>=3)
            store.subscribe(subscriber: subscriber!)
        #else
            store.subscribe(subscriber!)
        #endif
        XCTAssertEqual(store.subscriptions.flatMap({ $0.subscriber }).count, 1)

        subscriber = nil
        XCTAssertEqual(store.subscriptions.flatMap({ $0.subscriber }).count, 0)
    }

    func testRemoveSubscribers() {
        // it removes deferenced subscribers before notifying state changes

        store = Store(reducer: reducer, state: TestAppState())
        var subscriber1: TestSubscriber? = TestSubscriber()
        var subscriber2: TestSubscriber? = TestSubscriber()

        #if swift(>=3)
            store.subscribe(subscriber: subscriber1!)
            store.subscribe(subscriber: subscriber2!)
            store.dispatch(action: SetValueAction(3))
        #else
            store.subscribe(subscriber1!)
            store.subscribe(subscriber2!)
            store.dispatch(SetValueAction(3))
        #endif
        XCTAssertEqual(store.subscriptions.count, 2)
        XCTAssertEqual(subscriber1?.receivedStates.last?.testValue, 3)
        XCTAssertEqual(subscriber2?.receivedStates.last?.testValue, 3)

        subscriber1 = nil
        #if swift(>=3)
            store.dispatch(action: SetValueAction(5))
        #else
            store.dispatch(SetValueAction(5))
        #endif
        XCTAssertEqual(store.subscriptions.count, 1)
        XCTAssertEqual(subscriber2?.receivedStates.last?.testValue, 5)

        subscriber2 = nil
        #if swift(>=3)
            store.dispatch(action: SetValueAction(8))
        #else
            store.dispatch(SetValueAction(8))
        #endif
        XCTAssertEqual(store.subscriptions.count, 0)
    }

    func testDispatchInitialValue() {
        // it dispatches initial value upon subscription
        store = Store(reducer: reducer, state: TestAppState())
        let subscriber = TestSubscriber()

        #if swift(>=3)
            store.subscribe(subscriber: subscriber)
            store.dispatch(action: SetValueAction(3))
        #else
            store.subscribe(subscriber)
            store.dispatch(SetValueAction(3))
        #endif

        XCTAssertEqual(subscriber.receivedStates.last?.testValue, 3)
    }

    func testAllowDispatchWithinObserver() {
        // it allows dispatching from within an observer
        store = Store(reducer: reducer, state: TestAppState())
        let subscriber = DispatchingSubscriber(store: store)

        #if swift(>=3)
            store.subscribe(subscriber: subscriber)
            store.dispatch(action: SetValueAction(2))
        #else
            store.subscribe(subscriber)
            store.dispatch(SetValueAction(2))
        #endif

        XCTAssertEqual(store.state.testValue, 5)
    }

    func testDontDispatchToUnsubscribers() {
        // it does not dispatch value after subscriber unsubscribes
        store = Store(reducer: reducer, state: TestAppState())
        let subscriber = TestSubscriber()

        #if swift(>=3)
            store.dispatch(action: SetValueAction(5))
            store.subscribe(subscriber: subscriber)
            store.dispatch(action: SetValueAction(10))

            store.unsubscribe(subscriber: subscriber)
            // Following value is missed due to not being subscribed:
            store.dispatch(action: SetValueAction(15))
            store.dispatch(action: SetValueAction(25))

            store.subscribe(subscriber: subscriber)

            store.dispatch(action: SetValueAction(20))
        #else
            store.dispatch(SetValueAction(5))
            store.subscribe(subscriber)
            store.dispatch(SetValueAction(10))

            store.unsubscribe(subscriber)
            // Following value is missed due to not being subscribed:
            store.dispatch(SetValueAction(15))
            store.dispatch(SetValueAction(25))

            store.subscribe(subscriber)

            store.dispatch(SetValueAction(20))
        #endif

        XCTAssertEqual(subscriber.receivedStates.count, 4)
        XCTAssertEqual(subscriber.receivedStates[subscriber.receivedStates.count - 4].testValue, 5)
        XCTAssertEqual(subscriber.receivedStates[subscriber.receivedStates.count - 3].testValue, 10)
        XCTAssertEqual(subscriber.receivedStates[subscriber.receivedStates.count - 2].testValue, 25)
        XCTAssertEqual(subscriber.receivedStates[subscriber.receivedStates.count - 1].testValue, 20)
    }

    func testIgnoreIdenticalSubscribers() {
        // it ignores identical subscribers
        store = Store(reducer: reducer, state: TestAppState())
        let subscriber = TestSubscriber()

        #if swift(>=3)
            store.subscribe(subscriber: subscriber)
            store.subscribe(subscriber: subscriber)
        #else
            store.subscribe(subscriber)
            store.subscribe(subscriber)
        #endif

        XCTAssertEqual(store.subscriptions.count, 1)
    }

    func testIgnoreIdenticalSubstateSubscribers() {
        // it ignores identical subscribers that provide substate selectors
        store = Store(reducer: reducer, state: TestAppState())
        let subscriber = TestSubscriber()

        #if swift(>=3)
            store.subscribe(subscriber: subscriber) { $0 }
            store.subscribe(subscriber: subscriber) { $0 }
        #else
            store.subscribe(subscriber) { $0 }
            store.subscribe(subscriber) { $0 }
        #endif

        XCTAssertEqual(store.subscriptions.count, 1)
    }

}



class StoreDispatchTest: XCTestCase {

    typealias TestSubscriber = TestStoreSubscriber<TestAppState>
    typealias CallbackSubscriber = CallbackStoreSubscriber<TestAppState>

    var store: Store<TestAppState>!
    var reducer: TestReducer!

    override func setUp() {
        super.setUp()
        reducer = TestReducer()
        store = Store(reducer: reducer, state: TestAppState())
    }

    func testReturnsDispatchedAction() {
        // it returns the dispatched action
        let action = SetValueAction(10)
        #if swift(>=3)
            let returnValue = store.dispatch(action: action)
        #else
            let returnValue = store.dispatch(action)
        #endif

        XCTAssertEqual((returnValue as? SetValueAction)?.value, action.value)
    }

    func testThrowsExceptionWhenReducersDispatch() {
        // it throws an exception when a reducer dispatches an action
        // Expectation lives in the `DispatchingReducer` class
        let reducer = DispatchingReducer()
        store = Store(reducer: reducer, state: TestAppState())
        reducer.store = store
        #if swift(>=3)
            store.dispatch(action: SetValueAction(10))
        #else
            store.dispatch(SetValueAction(10))
        #endif
    }

    func testAcceptsActionCreators() {
        // it accepts action creators
        #if swift(>=3)
            store.dispatch(action: SetValueAction(5))
        #else
            store.dispatch(SetValueAction(5))
        #endif

        let doubleValueActionCreator: Store<TestAppState>.ActionCreator = { state, store in
            return SetValueAction(state.testValue! * 2)
        }

        #if swift(>=3)
            _ = store.dispatch(actionCreator: doubleValueActionCreator)
        #else
            store.dispatch(doubleValueActionCreator)
        #endif

        XCTAssertEqual(store.state.testValue, 10)
    }

    func testAcceptsAsyncActionCreators() {
        #if swift(>=3)
            let asyncExpectation = expectation(withDescription: "It accepts async action creators")
        #else
            let asyncExpectation = expectationWithDescription("It accepts async action creators")
        #endif

        #if swift(>=3)
            let asyncActionCreator: Store<TestAppState>.AsyncActionCreator = { _, _, callback in
                DispatchQueue.global(attributes: .qosDefault).async() {
                    // Provide the callback with an action creator
                    callback { state, store in
                        return SetValueAction(5)
                    }
                }
            }
        #else
            let asyncActionCreator: Store<TestAppState>.AsyncActionCreator = { _, _, callback in
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                    // Provide the callback with an action creator
                    callback { state, store in
                        return SetValueAction(5)
                    }
                }
            }
        #endif

        let subscriber = CallbackSubscriber { [unowned self] state in
            if self.store.state.testValue != nil {
                XCTAssertEqual(self.store.state.testValue, 5)
                asyncExpectation.fulfill()
            }
        }

        #if swift(>=3)
            store.subscribe(subscriber: subscriber)
            store.dispatch(asyncActionCreator: asyncActionCreator)
            waitForExpectations(withTimeout: 1) { error in
                if let error = error {
                    XCTFail("waitForExpectationsWithTimeout errored: \(error)")
                }
            }
        #else
            store.subscribe(subscriber)
            store.dispatch(asyncActionCreator)
            waitForExpectationsWithTimeout(1) { error in
                if let error = error {
                    XCTFail("waitForExpectationsWithTimeout errored: \(error)")
                }
            }
        #endif
    }

    func testCallsCalbackOnce() {
        #if swift(>=3)
            let asyncExpectation = expectation(
                withDescription: "It calls the callback once state update from async action is " +
                                 "complete")

            let asyncActionCreator: Store<TestAppState>.AsyncActionCreator = { _, _, callback in
                DispatchQueue.global(attributes: .qosDefault).async() {
                    // Provide the callback with an action creator
                    callback { state, store in
                        return SetValueAction(5)
                    }
                }
            }

            store.dispatch(asyncActionCreator: asyncActionCreator) { newState in
                XCTAssertEqual(self.store.state.testValue, 5)
                if newState.testValue == 5 {
                    asyncExpectation.fulfill()
                }
            }

            waitForExpectations(withTimeout: 1) { error in
                if let error = error {
                    XCTFail("waitForExpectationsWithTimeout errored: \(error)")
                }
            }
        #else
            let asyncExpectation = expectationWithDescription(
                "It calls the callback once state update from async action is complete")

            let asyncActionCreator: Store<TestAppState>.AsyncActionCreator = { _, _, callback in
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                    // Provide the callback with an action creator
                    callback { state, store in
                        return SetValueAction(5)
                    }
                }
            }

            store.dispatch(asyncActionCreator) { newState in
                XCTAssertEqual(self.store.state.testValue, 5)
                if newState.testValue == 5 {
                    asyncExpectation.fulfill()
                }
            }

            waitForExpectationsWithTimeout(1) { error in
                if let error = error {
                    XCTFail("waitForExpectationsWithTimeout errored: \(error)")
                }
            }
        #endif
    }
}

// Used for deinitialization test
class DeInitStore<State: StateType>: Store<State> {
    var deInitAction: (() -> Void)?

    deinit {
        deInitAction?()
    }

    required convenience init(
        reducer: AnyReducer,
        state: State?,
        deInitAction: () -> Void) {
            self.init(reducer: reducer, state: state, middleware: [])
            self.deInitAction = deInitAction
    }

    required init(reducer: AnyReducer, state: State?, middleware: [Middleware]) {
        super.init(reducer: reducer, state: state, middleware: middleware)
    }
}

// Needs to be class so that shared reference can be modified to inject store
class DispatchingReducer: XCTestCase, Reducer {
    var store: Store<TestAppState>? = nil

    func handleAction(action: Action, state: TestAppState?) -> TestAppState {
        expectFatalError {
            #if swift(>=3)
                self.store?.dispatch(action: SetValueAction(20))
            #else
                self.store?.dispatch(SetValueAction(20))
            #endif
        }
        return state ?? TestAppState()
    }
}
