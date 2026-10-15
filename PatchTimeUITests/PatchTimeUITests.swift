//
//  PatchTimeUITests.swift
//  PatchTimeUITests
//
//  Created by Admin on 30/04/2025.
//

import XCTest

final class PatchTimeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testOvertimeWheelsExistInAddFlow() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Heures Sup"].tap()
        app.navigationBars.buttons["plus"].tap()

        XCTAssertTrue(app.pickerWheels.element(boundBy: 0).exists)
        XCTAssertTrue(app.pickerWheels.element(boundBy: 1).exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
