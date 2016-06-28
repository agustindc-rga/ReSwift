//
//  TypeHelperTests.swift
//  ReSwift
//
//  Created by Benjamin Encz on 12/20/15.
//  Copyright © 2015 Benjamin Encz. All rights reserved.
//

import XCTest
@testable import ReSwift

struct AppState1: StateType {}
struct AppState2: StateType {}

class TypeHelperTests: XCTestCase {

    // Describe f_withSpecificTypes

    func testSourceTypeCasting() {
        // it calls methods if the source type can be casted into the function signature type
        var called = false
        let reducerFunction: (Action, AppState1?) -> AppState1 = { action, state in
            called = true

            return state ?? AppState1()
        }

        withSpecificTypes(StandardAction(type: ""), state: AppState1(), function: reducerFunction)

        XCTAssertTrue(called)
    }

    func testCallsIfSourceTypeIsNil() {
        // it calls the method if the source type is nil
        var called = false
        let reducerFunction: (Action, AppState1?) -> AppState1 = { action, state in
            called = true

            return state ?? AppState1()
        }

        withSpecificTypes(StandardAction(type: ""), state: nil, function: reducerFunction)

        XCTAssertTrue(called)
    }

    func textDoesntCallIfCastFails() {
        // it doesn't call if source type can't be casted to function signature type
        var called = false
        let reducerFunction: (Action, AppState1?) -> AppState1 = { action, state in
            called = true

            return state ?? AppState1()
        }

        withSpecificTypes(StandardAction(type: ""), state: AppState2(), function: reducerFunction)

        XCTAssertFalse(called)
    }
}
