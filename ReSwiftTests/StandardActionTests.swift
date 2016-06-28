//
//  StandardActionTests.swift
//  ReSwift
//
//  Created by Benjamin Encz on 12/29/15.
//  Copyright © 2015 Benjamin Encz. All rights reserved.
//

import XCTest
@testable import ReSwift

class StandardActionInitTests: XCTestCase {

    func testInitWithType() {
        // it can be initialized with just a type
        let action = StandardAction(type: "Test")

        XCTAssertEqual(action.type, "Test")
    }

    func testInitWithTypeAndPayload() {
        // it can be initialized with a type and a payload
        let action = StandardAction(type:"Test", payload: ["testKey": 5])

        let payload = action.payload!["testKey"]! as! Int

        XCTAssertEqual(payload, 5)
        XCTAssertEqual(action.type, "Test")
    }

}

class StandardActionInitSerializationTests: XCTestCase {

    func testCanInitWithDictionary() {
        // it can initialize action with a dictionary
        let actionDictionary: [String: AnyObject?] = [
            "type": "TestType",
            "payload": nil,
            "isTypedAction": true
        ]

        let action = StandardAction(dictionary: actionDictionary)

        XCTAssertEqual(action?.type, "TestType")
        XCTAssertNil(action?.payload)
        XCTAssertEqual(action?.isTypedAction, true)
    }

    func testConvertActionToDict() {
        // it can convert an action to a dictionary
        let action = StandardAction(type:"Test", payload: ["testKey": 5],
            isTypedAction: true)

        let dictionary = action.dictionaryRepresentation

        let type = dictionary["type"] as! String
        let payload = dictionary["payload"] as! [String: AnyObject]
        let isTypedAction = dictionary["isTypedAction"] as! Int

        XCTAssertEqual(type, "Test")
        XCTAssertEqual(payload["testKey"] as? Int, 5)
        XCTAssertEqual(isTypedAction, 1)
    }

    func testWithPayloadWithoutCustomType() {
        // it can serialize / deserialize actions with payload and without custom type
        let action = StandardAction(type:"Test", payload: ["testKey": 5])
        let dictionary = action.dictionaryRepresentation

        let deserializedAction = StandardAction(dictionary: dictionary)

        let payload = deserializedAction?.payload?["testKey"] as? Int

        XCTAssertEqual(payload, 5)
        XCTAssertEqual(deserializedAction?.type, "Test")
    }

    func testWithPayloadAndCustomType() {
        // it can serialize / deserialize actions with payload and with custom type
        let action = StandardAction(type:"Test", payload: ["testKey": 5],
                        isTypedAction: true)
        let dictionary = action.dictionaryRepresentation

        let deserializedAction = StandardAction(dictionary: dictionary)

        let payload = deserializedAction?.payload?["testKey"] as? Int

        XCTAssertEqual(payload, 5)
        XCTAssertEqual(deserializedAction?.type, "Test")
        XCTAssertEqual(deserializedAction?.isTypedAction, true)
    }

    func testWithoutPayloadOrCustomType() {
        // it can serialize / deserialize actions without payload and without custom type
        let action = StandardAction(type:"Test", payload: nil)
        let dictionary = action.dictionaryRepresentation

        let deserializedAction = StandardAction(dictionary: dictionary)

        XCTAssertNil(deserializedAction?.payload)
        XCTAssertEqual(deserializedAction?.type, "Test")
    }

    func testWithoutPayloadWithCustomType() {
        // it can serialize / deserialize actions without payload and with custom type
        let action = StandardAction(type:"Test", payload: nil,
            isTypedAction: true)
        let dictionary = action.dictionaryRepresentation

        let deserializedAction = StandardAction(dictionary: dictionary)

        XCTAssertNil(deserializedAction?.payload)
        XCTAssertEqual(deserializedAction?.type, "Test")
        XCTAssertEqual(deserializedAction?.isTypedAction, true)
    }

    func testReturnsNilWhenInvalid() {
        // it initializer returns nil when invalid dictionary is passed in
        let deserializedAction = StandardAction(dictionary: [:])

        XCTAssertNil(deserializedAction)
    }
}

class StandardActionConvertibleInit: XCTestCase {

    func testInitWithStandardAction() {
        // it can be initialized with a standard action
        let standardAction = StandardAction(type: "Test", payload: ["value": 10])
        let action = SetValueAction(standardAction)

        XCTAssertEqual(action.value, 10)
    }

}

class StandardActionConvertibleTests: XCTestCase {

    func testConvertToStandardAction() {
        // it can be converted to a standard action
        let action = SetValueAction(5)

        let standardAction = action.toStandardAction()

        XCTAssertEqual(standardAction.type, "SetValueAction")
        XCTAssertEqual(standardAction.isTypedAction, true)
        XCTAssertEqual(standardAction.payload?["value"] as? Int, 5)
    }

}
