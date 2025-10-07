//
//  ReLifeUITestsLaunchTests.swift
//  ReLifeUITests
//
//  Erstellt von Dimitar Chalakov am 14.09.25.
//

import XCTest

// Misst die Startzeit und erstellt einen Screenshot zum Launch
final class ReLifeUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Hier könnten weitere Schritte vor dem Screenshot ergänzt werden.

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
