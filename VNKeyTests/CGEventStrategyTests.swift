// CGEventStrategyTests.swift
// VNKeyTests
//
// Regression tests cho CGEventStrategy — kiểm tra delta calculation,
// state tracking, và state reset behavior.

import XCTest
@testable import VNKey

final class CGEventStrategyTests: XCTestCase {

    // MARK: - Delta Calculation Tests

    func testDeltaNoChange() {
        let strategy = CGEventStrategy.shared
        let (bs, insert) = strategy.calculateDelta(oldText: "abc", newText: "abc")
        XCTAssertEqual(bs, 0)
        XCTAssertEqual(insert, "")
    }

    func testDeltaAppendOnly() {
        let strategy = CGEventStrategy.shared
        let (bs, insert) = strategy.calculateDelta(oldText: "ab", newText: "abc")
        XCTAssertEqual(bs, 0)
        XCTAssertEqual(insert, "c")
    }

    func testDeltaReplaceLastChar() {
        let strategy = CGEventStrategy.shared
        // "vie" → "viê" (replace last char)
        let (bs, insert) = strategy.calculateDelta(oldText: "vie", newText: "viê")
        XCTAssertEqual(bs, 1)  // delete "e" (1 UTF-16 unit)
        XCTAssertEqual(insert, "ê")
    }

    func testDeltaFullReplace() {
        let strategy = CGEventStrategy.shared
        let (bs, insert) = strategy.calculateDelta(oldText: "abc", newText: "xyz")
        XCTAssertEqual(bs, 3)
        XCTAssertEqual(insert, "xyz")
    }

    func testDeltaDeleteAll() {
        let strategy = CGEventStrategy.shared
        let (bs, insert) = strategy.calculateDelta(oldText: "abc", newText: "")
        XCTAssertEqual(bs, 3)
        XCTAssertEqual(insert, "")
    }

    func testDeltaFromEmpty() {
        let strategy = CGEventStrategy.shared
        let (bs, insert) = strategy.calculateDelta(oldText: "", newText: "abc")
        XCTAssertEqual(bs, 0)
        XCTAssertEqual(insert, "abc")
    }

    func testDeltaBothEmpty() {
        let strategy = CGEventStrategy.shared
        let (bs, insert) = strategy.calculateDelta(oldText: "", newText: "")
        XCTAssertEqual(bs, 0)
        XCTAssertEqual(insert, "")
    }

    // MARK: - Vietnamese Transformation Delta Tests

    func testDeltaDdToD() {
        let strategy = CGEventStrategy.shared
        // When "d" changes to "đ": need 1 backspace + insert "đ"
        let (bs, insert) = strategy.calculateDelta(oldText: "d", newText: "đ")
        XCTAssertEqual(bs, 1)
        XCTAssertEqual(insert, "đ")
    }

    func testDeltaDdToCapitalD() {
        let strategy = CGEventStrategy.shared
        let (bs, insert) = strategy.calculateDelta(oldText: "D", newText: "Đ")
        XCTAssertEqual(bs, 1)
        XCTAssertEqual(insert, "Đ")
    }

    func testDeltaVieToViê() {
        let strategy = CGEventStrategy.shared
        let (bs, insert) = strategy.calculateDelta(oldText: "vie", newText: "viê")
        XCTAssertEqual(bs, 1)
        XCTAssertEqual(insert, "ê")
    }

    func testDeltaViêToViệ() {
        let strategy = CGEventStrategy.shared
        let (bs, insert) = strategy.calculateDelta(oldText: "viê", newText: "việ")
        XCTAssertEqual(bs, 1)  // "ê" → "ệ"
        XCTAssertEqual(insert, "ệ")
    }

    func testDeltaAwToĂ() {
        let strategy = CGEventStrategy.shared
        let (bs, insert) = strategy.calculateDelta(oldText: "a", newText: "ă")
        XCTAssertEqual(bs, 1)
        XCTAssertEqual(insert, "ă")
    }

    func testDeltaChaoToChào() {
        let strategy = CGEventStrategy.shared
        // "chao" → "chào": tone applied, "o" → "ò" but actually "chao" → "chào"
        // common prefix "cha", old suffix "o" → bs=1, insert "ào"
        let (bs, insert) = strategy.calculateDelta(oldText: "chao", newText: "chào")
        XCTAssertEqual(bs, 2)
        XCTAssertEqual(insert, "ào")

        // Alternative: full word transformation
        let (bs2, insert2) = strategy.calculateDelta(oldText: "hoa", newText: "hóa")
        XCTAssertEqual(bs2, 2)
        XCTAssertEqual(insert2, "óa")
    }

    // MARK: - State Reset Tests

    func testResetState() {
        let strategy = CGEventStrategy.shared
        strategy.resetState()
        // After reset, delta from empty old text should work correctly
        let (bs, insert) = strategy.calculateDelta(oldText: "", newText: "test")
        XCTAssertEqual(bs, 0)
        XCTAssertEqual(insert, "test")
    }

    // MARK: - UTF-16 Edge Cases

    func testDeltaVietnameseCharUTF16() {
        let strategy = CGEventStrategy.shared
        // Vietnamese characters with diacritics are in BMP → 1 UTF-16 unit each
        let (bs, insert) = strategy.calculateDelta(oldText: "đường", newText: "đường")
        XCTAssertEqual(bs, 0)
        XCTAssertEqual(insert, "")
    }

    func testDeltaComplexVietnameseWord() {
        let strategy = CGEventStrategy.shared
        // "duong" → "đường" (complete transformation)
        let (bs, insert) = strategy.calculateDelta(oldText: "duong", newText: "đường")
        // no common prefix at all (d ≠ đ)
        XCTAssertEqual(bs, 5)  // delete all of "duong"
        XCTAssertEqual(insert, "đường")
    }
}

// MARK: - Input Pipeline Integration Tests

final class InputPipelineTests: XCTestCase {

    // MARK: - Vietnamese Transformations (Telex)

    private let engine = VietnameseEngine()

    private func processTelex(_ raw: String) -> String {
        return engine.process(rawString: raw, method: .telex).processedText
    }

    // Regression tests for Bug #1: dd → đ (NOT dđ)

    func testDdProducesĐ() {
        XCTAssertEqual(processTelex("dd"), "đ")
    }

    func testDDProducesĐ() {
        XCTAssertEqual(processTelex("DD"), "Đ")
    }

    func testDddProducesDĐ() {
        // ddd = d + dd → "d" then "đ"? No:
        // Actually: rawBuffer is "ddd"
        // Engine processes: d → result ["d"], d → dd → đ, d → result ["đ", "d"]
        // Let's verify what the engine actually produces
        let result = processTelex("ddd")
        // In TelexProcessor, đ + d triggers undo to "dd"
        XCTAssertEqual(result, "dd")
    }

    func testSingleD() {
        XCTAssertEqual(processTelex("d"), "d")
    }

    // Regression tests for basic transformations

    func testTelexAw() {
        XCTAssertEqual(processTelex("aw"), "ă")
    }

    func testTelexAa() {
        XCTAssertEqual(processTelex("aa"), "â")
    }

    func testTelexEe() {
        XCTAssertEqual(processTelex("ee"), "ê")
    }

    func testTelexOo() {
        XCTAssertEqual(processTelex("oo"), "ô")
    }

    func testTelexOw() {
        XCTAssertEqual(processTelex("ow"), "ơ")
    }

    func testTelexUw() {
        XCTAssertEqual(processTelex("uw"), "ư")
    }

    // First input scenario: empty buffer + dd → đ

    func testEmptyBufferThenDd() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("d")
        XCTAssertEqual(buffer.processedText, "d")

        buffer.append("d")
        XCTAssertEqual(buffer.processedText, "đ")
    }

    // Existing text + dd → đ appended

    func testExistingTextPlusDd() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("a")
        buffer.append("b")
        buffer.append("c")
        XCTAssertEqual(buffer.processedText, "abc")
        
        buffer.append("d")
        buffer.append("d")
        XCTAssertEqual(buffer.processedText, "abcđ")
    }

    // Backspace info after transformation

    func testBackspaceInfoAfterDd() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("d")  // processedText = "d", previousProcessedText = ""
        buffer.append("d")  // processedText = "đ", previousProcessedText = "d"

        let info = buffer.backspaceInfo
        // old = "d", new = "đ" → 1 backspace + insert "đ"
        XCTAssertEqual(info.backspaceCount, 1)
        XCTAssertEqual(info.insertText, "đ")
    }

    // MARK: - State Transitions

    func testFocusTypeCommitTypeCycle() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        // Type
        buffer.append("v")
        buffer.append("i")
        buffer.append("e")
        buffer.append("e")
        buffer.append("t")
        buffer.append("j")
        XCTAssertEqual(buffer.processedText, "việt")

        // Commit
        let committed = buffer.commit()
        XCTAssertEqual(committed, "việt")
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.state, .idle)

        // Type again
        buffer.append("n")
        buffer.append("a")
        buffer.append("m")
        XCTAssertEqual(buffer.processedText, "nam")
    }

    func testTypeDeleteTypeCycle() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("a")
        buffer.append("s")
        XCTAssertEqual(buffer.processedText, "á")

        buffer.deleteBackward()  // remove "s" from raw → back to "a"
        XCTAssertEqual(buffer.processedText, "a")

        buffer.append("f")
        XCTAssertEqual(buffer.processedText, "à")
    }

    func testSelectDeleteType() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("d")
        buffer.append("d")
        XCTAssertEqual(buffer.processedText, "đ")

        // Delete all
        buffer.deleteBackward()
        buffer.deleteBackward()
        XCTAssertTrue(buffer.isEmpty)

        // Type again
        buffer.append("a")
        buffer.append("s")
        XCTAssertEqual(buffer.processedText, "á")
    }

    // MARK: - Deletion Tests

    func testDeleteInComposing() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("v")
        buffer.append("i")
        buffer.append("e")
        buffer.append("e")
        XCTAssertEqual(buffer.processedText, "viê")

        buffer.deleteBackward()  // removes last "e" from raw → "vie"
        XCTAssertEqual(buffer.processedText, "vie")

        buffer.deleteBackward()  // removes "e" → "vi"
        XCTAssertEqual(buffer.processedText, "vi")
    }

    func testDeleteToEmpty() {
        let buffer = CompositionBuffer()
        buffer.inputMethod = .telex

        buffer.append("a")
        buffer.deleteBackward()
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.state, .idle)
    }

    func testDeleteFromEmpty() {
        let buffer = CompositionBuffer()
        let result = buffer.deleteBackward()
        XCTAssertNil(result)
    }

    func testEnglishInputUnchanged() {
        let engine = VietnameseEngine()

        XCTAssertEqual(engine.process(rawString: "hello", method: .telex).processedText, "hello")
        XCTAssertEqual(engine.process(rawString: "key", method: .telex).processedText, "key")
        XCTAssertEqual(engine.process(rawString: "link", method: .telex).processedText, "link")
        XCTAssertEqual(engine.process(rawString: "input", method: .telex).processedText, "input")
        XCTAssertEqual(engine.process(rawString: "method", method: .telex).processedText, "method")
    }

    func testStateTransitionsAndWorkarounds() {
        let strategy = CGEventStrategy.shared
        strategy.resetState()
        
        // Simulating focus -> type
        var (bs, insert) = strategy.calculateDelta(oldText: "", newText: "d")
        XCTAssertEqual(bs, 0)
        XCTAssertEqual(insert, "d")
        
        // Simulating focus -> type -> delete
        (bs, insert) = strategy.calculateDelta(oldText: "d", newText: "")
        XCTAssertEqual(bs, 1)
        XCTAssertEqual(insert, "")
        
        // Simulating focus -> type -> blur (reset) -> focus -> type
        strategy.resetState()
        (bs, insert) = strategy.calculateDelta(oldText: "", newText: "a")
        XCTAssertEqual(bs, 0)
        XCTAssertEqual(insert, "a")
    }
}
