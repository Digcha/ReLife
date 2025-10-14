//
//  ReLifeUITests.swift
//  ReLifeUITests
//
//  Erstellt von Dimitar Chalakov am 14.09.25.
//

import XCTest

// UI-Testgerüst für grundlegende Start-Checks
final class ReLifeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Vor jedem Test Startbedingungen setzen.
        continueAfterFailure = false
        // Anfangszustände wie Ausrichtung könnten hier vorbereitet werden.
    }

    override func tearDownWithError() throws {
        // Nach jedem Test aufräumen, falls nötig.
    }

    @MainActor
    func testExample() throws {
        // UI-Tests starten zuerst die App.
        let app = XCUIApplication()
        app.launch()

        // Mit XCTAssert & Co. gewünschtes Verhalten prüfen.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Misst die Startdauer der App.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
