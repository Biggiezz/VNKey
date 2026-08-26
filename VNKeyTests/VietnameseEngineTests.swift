// VietnameseEngineTests.swift
// VNKeyTests
//
// Unit tests cho VietnameseEngine — engine xử lý lõi.
// Test toàn bộ pipeline: raw input → Vietnamese output.

import XCTest
@testable import VNKey

final class VietnameseEngineTests: XCTestCase {

    let engine = VietnameseEngine()

    // MARK: - Helper

    private func processTelex(_ raw: String) -> String {
        return engine.process(rawString: raw, method: .telex).processedText
    }

    private func processVNI(_ raw: String) -> String {
        return engine.process(rawString: raw, method: .vni).processedText
    }

    // MARK: - Telex: Basic Words

    func testTelexSimpleConsonant() {
        XCTAssertEqual(processTelex("b"), "b")
        XCTAssertEqual(processTelex("ch"), "ch")
    }

    func testTelexSimpleVowel() {
        XCTAssertEqual(processTelex("a"), "a")
        XCTAssertEqual(processTelex("ai"), "ai")
    }

    func testTelexDiacriticOnly() {
        XCTAssertEqual(processTelex("aa"), "â")
        XCTAssertEqual(processTelex("ee"), "ê")
        XCTAssertEqual(processTelex("oo"), "ô")
        XCTAssertEqual(processTelex("aw"), "ă")
        XCTAssertEqual(processTelex("ow"), "ơ")
        XCTAssertEqual(processTelex("uw"), "ư")
        XCTAssertEqual(processTelex("dd"), "đ")
    }

    func testTelexWStandalone() {
        XCTAssertEqual(processTelex("w"), "ư")
        XCTAssertEqual(processTelex("W"), "Ư")
        XCTAssertEqual(processTelex("tw"), "tư")
        XCTAssertEqual(processTelex("ew"), "eư")
        
        // Test 'ww' double-press and 'www' undo cases
        XCTAssertEqual(processTelex("ww"), "w")
        XCTAssertEqual(processTelex("WW"), "W")
        XCTAssertEqual(processTelex("tww"), "tw")
        XCTAssertEqual(processTelex("eww"), "ew")
        XCTAssertEqual(processTelex("uww"), "uw")
        XCTAssertEqual(processTelex("www"), "wư")
        XCTAssertEqual(processTelex("wwww"), "ww")
        
        // New test cases for tone cancellation 'z' when there is no tone, and double-press with coda consonants
        XCTAssertEqual(processTelex("siez"), "siez")
        XCTAssertEqual(processTelex("siezs"), "siéz")
        XCTAssertEqual(processTelex("nhana"), "nhân")
        XCTAssertEqual(processTelex("hiene"), "hiên")
    }

    func testTelexToneOnly() {
        XCTAssertEqual(processTelex("as"), "á")
        XCTAssertEqual(processTelex("af"), "à")
        XCTAssertEqual(processTelex("ar"), "ả")
        XCTAssertEqual(processTelex("ax"), "ã")
        XCTAssertEqual(processTelex("aj"), "ạ")
    }

    // MARK: - Telex: Complete Words

    func testTelexViet() {
        // "vieetj" → "việt"
        XCTAssertEqual(processTelex("vieetj"), "việt")
    }

    func testTelexNam() {
        XCTAssertEqual(processTelex("nam"), "nam")
    }

    func testTelexXinChao() {
        XCTAssertEqual(processTelex("chaof"), "chào")
    }

    func testTelexDuong() {
        // "dduwowngf" → "đường"
        XCTAssertEqual(processTelex("dduwowngf"), "đường")
    }

    func testTelexTuoiTre() {
        XCTAssertEqual(processTelex("tuooir"), "tuổi")
    }

    func testTelexHoa() {
        // "hoas" → "hóa" (old style: dấu trên nguyên âm đầu tiên)
        XCTAssertEqual(processTelex("hoas"), "hóa")
    }

    // MARK: - Telex: Free-form Tone Placement

    func testTelexToneAtEnd() {
        // Bỏ dấu tự do: dấu ở cuối từ
        XCTAssertEqual(processTelex("toanf"), "toàn")
    }

    func testTelexToneBeforeCoda() {
        // Dấu trước phụ âm cuối
        XCTAssertEqual(processTelex("toafn"), "toàn")
    }

    // MARK: - Telex: Uppercase

    func testTelexUppercase() {
        XCTAssertEqual(processTelex("Vieetj"), "Việt")
        XCTAssertEqual(processTelex("Anhr"), "Ảnh")
        XCTAssertEqual(processTelex("anhr"), "ảnh")
        XCTAssertEqual(processTelex("ANHR"), "ẢNH")
        XCTAssertEqual(processTelex("Aasn"), "Ấn")
        XCTAssertEqual(processTelex("Awn"), "Ăn")
        XCTAssertEqual(processTelex("Owr"), "Ở")
        XCTAssertEqual(processTelex("Uwsng"), "Ứng")
        XCTAssertEqual(processTelex("DDuowngf"), "Đường")
    }

    // MARK: - Telex: Undo Tone

    func testTelexToneToggle() {
        // "ass" → tone sắc applied then undone → "as"
        XCTAssertEqual(processTelex("ass"), "as")
    }

    // MARK: - Telex: No Transformation

    func testTelexNoVowelNoTone() {
        // 's' trước nguyên âm = consonant, không phải tone key
        XCTAssertEqual(processTelex("s"), "s")
        XCTAssertEqual(processTelex("sc"), "sc")
    }

    // MARK: - VNI: Basic

    func testVNIDiacritic() {
        XCTAssertEqual(processVNI("a6"), "â")
        XCTAssertEqual(processVNI("e6"), "ê")
        XCTAssertEqual(processVNI("o6"), "ô")
        XCTAssertEqual(processVNI("o7"), "ơ")
        XCTAssertEqual(processVNI("u7"), "ư")
        XCTAssertEqual(processVNI("a8"), "ă")
        XCTAssertEqual(processVNI("d9"), "đ")
    }

    func testVNITone() {
        XCTAssertEqual(processVNI("a1"), "á")
        XCTAssertEqual(processVNI("a2"), "à")
        XCTAssertEqual(processVNI("a3"), "ả")
        XCTAssertEqual(processVNI("a4"), "ã")
        XCTAssertEqual(processVNI("a5"), "ạ")
    }

    func testVNICompleteWord() {
        // "vie6t5" → "việt"
        XCTAssertEqual(processVNI("vie6t5"), "việt")
    }

    // MARK: - Empty Input

    func testEmptyInput() {
        XCTAssertEqual(processTelex(""), "")
        XCTAssertEqual(processVNI(""), "")
    }

    // MARK: - Backspace Calculation

    func testBackspaceCalculation() {
        let result = engine.calculateBackspaceAndInsert(
            oldText: "vie",
            newText: "viê"
        )
        // "e" needs 1 backspace, insert "ê"
        XCTAssertEqual(result.backspaceCount, 1)
        XCTAssertEqual(result.insertText, "ê")
    }

    func testBackspaceCalculationNoChange() {
        let result = engine.calculateBackspaceAndInsert(
            oldText: "abc",
            newText: "abc"
        )
        XCTAssertEqual(result.backspaceCount, 0)
        XCTAssertEqual(result.insertText, "")
    }

    func testBackspaceCalculationFullReplace() {
        let result = engine.calculateBackspaceAndInsert(
            oldText: "abc",
            newText: "xyz"
        )
        XCTAssertEqual(result.backspaceCount, 3)
        XCTAssertEqual(result.insertText, "xyz")
    }

    func testBackspaceCalculationAppend() {
        let result = engine.calculateBackspaceAndInsert(
            oldText: "ab",
            newText: "abc"
        )
        XCTAssertEqual(result.backspaceCount, 0)
        XCTAssertEqual(result.insertText, "c")
    }

    // MARK: - Has Transformation Flag

    func testHasTransformationTrue() {
        let result = engine.process(rawString: "as", method: .telex)
        XCTAssertTrue(result.hasTransformation)
    }

    func testHasTransformationFalse() {
        let result = engine.process(rawString: "abc", method: .telex)
        XCTAssertFalse(result.hasTransformation)
    }

    func testTelexDoubleHornWord() {
        // "dduowngf" (with single w after uo) -> "đường"
        XCTAssertEqual(processTelex("dduowngf"), "đường")
        // "dduowcj" (được) -> "được"
        XCTAssertEqual(processTelex("dduowcj"), "được")
        // "dduocjw" (đuọc + w -> được) -> "được"
        XCTAssertEqual(processTelex("dduocjw"), "được")
    }
}
