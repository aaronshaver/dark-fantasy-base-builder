import XCTest

final class GameUITests: XCTestCase {
    @MainActor
    func testPortraitPauseDeathAndNewGame() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--seed", "14"]
        app.launch()
        let pause = app.buttons["pauseToggle"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(app.frame.height, app.frame.width)
        pause.tap()
        XCTAssertEqual(pause.label, "Play")
        XCTAssertTrue(app.staticTexts["Paused"].exists)
        XCTAssertGreaterThan(pause.frame.minX, app.buttons["raise"].frame.minX)
        let frozenHealth = app.staticTexts["playerHealth"].label
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(app.staticTexts["playerHealth"].label, frozenHealth)
        let pausedShot = XCTAttachment(screenshot: app.screenshot())
        pausedShot.name = "Portrait world and play toggle"
        pausedShot.lifetime = .keepAlways
        add(pausedShot)
        pause.tap()
        XCTAssertEqual(pause.label, "Pause")
        XCTAssertTrue(app.staticTexts["You died"].waitForExistence(timeout: 65))
        XCTAssertEqual(app.staticTexts["playerHealth"].label, "Health, 0")
        let deathShot = XCTAttachment(screenshot: app.screenshot())
        deathShot.name = "You died"
        deathShot.lifetime = .keepAlways
        add(deathShot)
        app.buttons["newGame"].tap()
        XCTAssertFalse(app.staticTexts["You died"].exists)
        XCTAssertEqual(app.staticTexts["playerHealth"].label, "Health, 30")
        XCTAssertEqual(pause.label, "Pause")
    }
}
