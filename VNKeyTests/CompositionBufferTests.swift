// CompositionBufferTests.swift
// VNKeyTests
//
// Unit tests cho CompositionBuffer — quản lý trạng thái soạn thảo.

import XCTest
@testable import VNKey

final class CompositionBufferTests: XCTestCase {

    // MARK: - Initial State

    func testInitialState() {
        let buffer = CompositionBuffer()
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertFalse(buffer.isComposing)
        XCTAssertEqual(buffer.state, .idle)
        XCTAssertEqual(buffer.processedText, "")
        XCTAssertEqual(buffer.rawCount, 0)
    }

    // MARK: - Append

    func testAppendSingleChar() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("a")

        XCTAssertEqual(buffer.state, .composing)
        XCTAssertEqual(buffer.rawCount, 1)
        XCTAssertEqual(buffer.processedText, "a")
        XCTAssertTrue(buffer.isComposing)
    }

    func testAppendMultipleChars() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("v")
        buffer.append("i")
        buffer.append("e")

        XCTAssertEqual(buffer.rawCount, 3)
        XCTAssertEqual(buffer.processedText, "vie")
    }

    func testAppendWithDiacritic() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("v")
        buffer.append("i")
        buffer.append("e")
        buffer.append("e")  // ee → ê

        XCTAssertEqual(buffer.processedText, "viê")
    }

    func testAppendWithTone() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("v")
        buffer.append("i")
        buffer.append("e")
        buffer.append("e")  // ê
        buffer.append("j")  // nặng → ệ

        // Engine correctly applies nặng to ê → ệ, giving "việ"
        XCTAssertEqual(buffer.processedText, "việ")
    }

    // MARK: - Delete

    func testDeleteBackward() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("a")
        buffer.append("b")
        buffer.deleteBackward()

        XCTAssertEqual(buffer.rawCount, 1)
        XCTAssertEqual(buffer.processedText, "a")
    }

    func testDeleteToEmpty() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("a")
        buffer.deleteBackward()

        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.state, .idle)
        XCTAssertEqual(buffer.processedText, "")
    }

    func testDeleteFromEmpty() {
        let buffer = CompositionBuffer()
        let result = buffer.deleteBackward()

        XCTAssertNil(result)
        XCTAssertTrue(buffer.isEmpty)
    }

    // MARK: - Commit

    func testCommit() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("a")
        buffer.append("s")

        let committed = buffer.commit()

        XCTAssertEqual(committed, "á")
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.state, .idle)
        XCTAssertEqual(buffer.processedText, "")
    }

    func testCommitEmpty() {
        let buffer = CompositionBuffer()
        let committed = buffer.commit()
        XCTAssertEqual(committed, "")
    }

    // MARK: - Reset

    func testReset() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("v")
        buffer.append("i")
        buffer.reset()

        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.state, .idle)
        XCTAssertEqual(buffer.processedText, "")
        XCTAssertEqual(buffer.previousProcessedText, "")
    }

    // MARK: - Previous Processed Text Tracking

    func testPreviousProcessedTextTracking() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("v")
        XCTAssertEqual(buffer.previousProcessedText, "")

        buffer.append("i")
        XCTAssertEqual(buffer.previousProcessedText, "v")

        buffer.append("e")
        XCTAssertEqual(buffer.previousProcessedText, "vi")
    }

    // MARK: - Backspace Info

    func testBackspaceInfo() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("v")
        buffer.append("i")
        buffer.append("e")
        buffer.append("e")  // vie → viê

        let info = buffer.backspaceInfo
        // Previous: "vie", Current: "viê"
        // Common prefix: "vi" (2 chars)
        // Backspace count: UTF16("e") = 1
        // Insert text: "ê"
        XCTAssertEqual(info.backspaceCount, 1)
        XCTAssertEqual(info.insertText, "ê")
    }

    // MARK: - Input Method Switching

    func testInputMethodSwitch() {
        let buffer = CompositionBuffer()

        buffer.inputMethod = .telex
        buffer.append("a")
        buffer.append("s")
        XCTAssertEqual(buffer.processedText, "á")

        buffer.reset()

        buffer.inputMethod = .vni
        buffer.append("a")
        buffer.append("1")
        XCTAssertEqual(buffer.processedText, "á")
    }

    // MARK: - Tone Placement Style

    func testTonePlacementStyle() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        // Old style: "hoas" → "hóa"
        buffer.tonePlacement = .oldStyle
        buffer.append("h")
        buffer.append("o")
        buffer.append("a")
        buffer.append("s")
        XCTAssertEqual(buffer.processedText, "hóa")

        buffer.reset()

        // New style: "hoas" → "hoá"
        buffer.tonePlacement = .newStyle
        buffer.append("h")
        buffer.append("o")
        buffer.append("a")
        buffer.append("s")
        XCTAssertEqual(buffer.processedText, "hoá")
    }
}
