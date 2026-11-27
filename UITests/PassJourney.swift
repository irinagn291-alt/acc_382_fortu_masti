import XCTest

final class PassJourney: XCTestCase {
    let app = XCUIApplication()
    func launch(_ lang: String = "en-GB") {
        app.launchArguments = ["-AppleLanguages","(\(lang))","-AppleLocale",lang.replacingOccurrences(of: "-", with: "_")]
        app.launch()
    }
    func shot(_ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    func choose(_ number: Int, solo: Bool) {
        app.buttons["atlas"].tap()
        let mode = app.buttons[solo ? "Solo" : "Two players"].firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 6))
        mode.tap()
        app.buttons["pass\(number)"].tap()
        let begin = app.buttons["begin"]
        if !begin.isHittable { app.swipeUp() }
        begin.tap()
        let confirm = app.buttons["Begin crossing"]
        if confirm.waitForExistence(timeout: 0.8) { confirm.tap() }
    }
    func testCrossingAndTwoPlayerTable() {
        continueAfterFailure = false; launch()
        XCTAssertTrue(app.buttons["atlas"].waitForExistence(timeout: 8))
        choose(0, solo: true); shot("01-pass-board")
        app.buttons["point16"].tap()
        app.buttons["undo"].tap()
        XCTAssertEqual(app.staticTexts["counter"].label, "0 / 12")
        app.buttons["point16"].tap()
        app.terminate(); launch()
        XCTAssertEqual(app.staticTexts["counter"].label, "1 / 12")
        for n in [12,6,0] { app.buttons["point\(n)"].tap() }
        XCTAssertEqual(app.staticTexts["turn"].label, "Tiger escaped")
        shot("02-escape")
        choose(0, solo: false)
        app.buttons["point16"].tap()
        XCTAssertEqual(app.staticTexts["turn"].label, "Wardens to move")
        app.buttons["point5"].tap(); app.buttons["point6"].tap()
        XCTAssertEqual(app.staticTexts["turn"].label, "Tiger to move")
        app.buttons["atlas"].tap(); shot("03-pass-atlas")
    }
    func testTranslatedRules() {
        launch("ar"); XCTAssertTrue(app.buttons["rules"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["rules"].label,"قواعد اللعب"); app.buttons["rules"].tap(); XCTAssertTrue(app.navigationBars["قواعد اللعب"].waitForExistence(timeout: 6)); shot("04-arabic-rules")
        app.terminate(); launch("zh-Hant"); XCTAssertEqual(app.buttons["rules"].label,"對弈規則")
        app.terminate(); launch("pt-BR"); XCTAssertEqual(app.buttons["rules"].label,"Regras de campo")
    }
}
