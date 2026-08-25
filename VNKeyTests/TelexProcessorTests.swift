// TelexProcessorTests.swift
// VNKeyTests
//
// Unit tests cho TelexProcessor — kiểu gõ Telex.

import XCTest
@testable import VNKey

final class TelexProcessorTests: XCTestCase {

    let processor = TelexProcessor()

    // MARK: - Helper

    /// Áp dụng diacritic và trả về kết quả.
    private func applyDiacritic(_ char: Character, to input: String) -> String {
        var result = Array(input)
        let consumed = processor.tryApplyDiacritic(char, to: &result)
        return consumed ? String(result) : input + String(char)
    }

    // MARK: - Double-Press Diacritics (aa → â, ee → ê, oo → ô)

    func testDoublePressA() {
        var result: [Character] = ["a"]
        XCTAssertTrue(processor.tryApplyDiacritic("a", to: &result))
        XCTAssertEqual(String(result), "â")
    }

    func testDoublePressE() {
        var result: [Character] = ["e"]
        XCTAssertTrue(processor.tryApplyDiacritic("e", to: &result))
        XCTAssertEqual(String(result), "ê")
    }

    func testDoublePressO() {
        var result: [Character] = ["o"]
        XCTAssertTrue(processor.tryApplyDiacritic("o", to: &result))
        XCTAssertEqual(String(result), "ô")
    }

    func testDoublePressUppercase() {
        var result: [Character] = ["A"]
        XCTAssertTrue(processor.tryApplyDiacritic("a", to: &result))
        XCTAssertEqual(String(result), "Â")
    }

    // MARK: - Undo Diacritics

    func testUndoCircumflex() {
        // â + a → aa (undo circumflex, add literal 'a')
        var result: [Character] = ["â"]
        XCTAssertTrue(processor.tryApplyDiacritic("a", to: &result))
        XCTAssertEqual(String(result), "aa")
    }

    func testUndoBraceW() {
        // ă + w → aw (undo breve, add literal 'w')
        var result: [Character] = ["ă"]
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "aw")
    }

    // MARK: - W Modifier (aw → ă, ow → ơ, uw → ư)

    func testWModifierA() {
        var result: [Character] = ["a"]
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "ă")
    }

    func testWModifierO() {
        var result: [Character] = ["o"]
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "ơ")
    }

    func testWModifierU() {
        var result: [Character] = ["u"]
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "ư")
    }

    func testWModifierUppercaseO() {
        var result: [Character] = ["O"]
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "Ơ")
    }

    func testWModifierNoMatch() {
        // 'w' sau 'e' → không match với e, và 'w' gõ đơn lẻ thì thành 'ư'
        var result: [Character] = ["e"]
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "eư")
    }

    func testWStandalone() {
        var result: [Character] = []
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "ư")
    }

    func testWStandaloneUppercase() {
        var result: [Character] = []
        XCTAssertTrue(processor.tryApplyDiacritic("W", to: &result))
        XCTAssertEqual(String(result), "Ư")
    }

    func testWAfterConsonant() {
        var result: [Character] = ["t"]
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "tư")
    }

    func testWWEscape() {
        var result: [Character] = []
        // 1st press 'w' -> 'ư'
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result, rawInput: ["w", "w", "w", "w"], currentIndex: 0))
        XCTAssertEqual(String(result), "ư")
        
        // 2nd press 'w' -> 'w'
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result, rawInput: ["w", "w", "w", "w"], currentIndex: 1))
        XCTAssertEqual(String(result), "w")

        // 3rd press 'w' -> 'wư'
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result, rawInput: ["w", "w", "w", "w"], currentIndex: 2))
        XCTAssertEqual(String(result), "wư")

        // 4th press 'w' -> 'ww'
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result, rawInput: ["w", "w", "w", "w"], currentIndex: 3))
        XCTAssertEqual(String(result), "ww")
    }

    func testWWEscapeAfterConsonant() {
        var result: [Character] = ["t"]
        // 1st char 'w' after 't' -> 'tư'
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result, rawInput: ["t", "w", "w", "w", "w"], currentIndex: 1))
        XCTAssertEqual(String(result), "tư")
        
        // 2nd char 'w' -> 'tw'
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result, rawInput: ["t", "w", "w", "w", "w"], currentIndex: 2))
        XCTAssertEqual(String(result), "tw")

        // 3rd char 'w' -> 'twư'
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result, rawInput: ["t", "w", "w", "w", "w"], currentIndex: 3))
        XCTAssertEqual(String(result), "twư")

        // 4th char 'w' -> 'tww'
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result, rawInput: ["t", "w", "w", "w", "w"], currentIndex: 4))
        XCTAssertEqual(String(result), "tww")
    }

    func testUWWEscape() {
        var result: [Character] = ["u"]
        // 1st char 'w' after 'u' -> 'ư'
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result, rawInput: ["u", "w", "w"], currentIndex: 1))
        XCTAssertEqual(String(result), "ư")
        
        // 2nd char 'w' -> 'uw' (undo)
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result, rawInput: ["u", "w", "w"], currentIndex: 2))
        XCTAssertEqual(String(result), "uw")
    }

    // MARK: - DD → Đ

    func testDDtoDBar() {
        var result: [Character] = ["d"]
        XCTAssertTrue(processor.tryApplyDiacritic("d", to: &result))
        XCTAssertEqual(String(result), "đ")
        
        // Test "d-o-d" -> "đo"
        var result2: [Character] = ["d", "o"]
        XCTAssertTrue(processor.tryApplyDiacritic("d", to: &result2))
        XCTAssertEqual(String(result2), "đo")
    }

    func testDDtoDBarUppercase() {
        var result: [Character] = ["D"]
        XCTAssertTrue(processor.tryApplyDiacritic("d", to: &result))
        XCTAssertEqual(String(result), "Đ")
        
        // Test "D-o-d" -> "Đo"
        var result2: [Character] = ["D", "o"]
        XCTAssertTrue(processor.tryApplyDiacritic("d", to: &result2))
        XCTAssertEqual(String(result2), "Đo")
    }

    func testDBarUndo() {
        // đ + d → dd (undo)
        var result: [Character] = ["đ"]
        XCTAssertTrue(processor.tryApplyDiacritic("d", to: &result))
        XCTAssertEqual(String(result), "dd")
        
        // Test "đ-o" + "d" -> "dod"
        var result2: [Character] = ["đ", "o"]
        XCTAssertTrue(processor.tryApplyDiacritic("d", to: &result2))
        XCTAssertEqual(String(result2), "dod")
    }

    // MARK: - Tone Keys

    func testToneKeys() {
        XCTAssertEqual(processor.toneForKey("s"), Tone.sac)
        XCTAssertEqual(processor.toneForKey("f"), Tone.huyen)
        XCTAssertEqual(processor.toneForKey("r"), Tone.hoi)
        XCTAssertEqual(processor.toneForKey("x"), Tone.nga)
        XCTAssertEqual(processor.toneForKey("j"), Tone.nang)
        // 'z' is a tone key that REMOVES tone → returns Tone.none (not nil)
        let zTone = processor.toneForKey("z")
        XCTAssertNotNil(zTone)
        XCTAssertEqual(zTone, Tone.none)
    }

    func testNonToneKeys() {
        XCTAssertNil(processor.toneForKey("a"))
        XCTAssertNil(processor.toneForKey("b"))
        XCTAssertNil(processor.toneForKey("1"))
    }

    // MARK: - Context: Diacritic in Word

    func testDiacriticInLongerWord() {
        // "vi" + "e" + "e" → "viê" (ee → ê applied to last 'e')
        var result: [Character] = ["v", "i", "e"]
        XCTAssertTrue(processor.tryApplyDiacritic("e", to: &result))
        XCTAssertEqual(String(result), "viê")
    }

    func testWModifierInWord() {
        // "thu" + "w" → "thư"
        var result: [Character] = ["t", "h", "u"]
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "thư")
    }

    func testDiacriticOnEmptyResult() {
        var result: [Character] = []
        XCTAssertFalse(processor.tryApplyDiacritic("a", to: &result))
        XCTAssertEqual(result.count, 0)
    }

    func testDoubleHornRule() {
        // "uo" + "w" -> "ươ"
        var result: [Character] = ["u", "o"]
        XCTAssertTrue(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "ươ")
    }

    func testDoublePressWithTrailingConsonant() {
        // nhan + a -> nhân
        var result: [Character] = ["n", "h", "a", "n"]
        XCTAssertTrue(processor.tryApplyDiacritic("a", to: &result))
        XCTAssertEqual(String(result), "nhân")
    }

    func testDoublePressInvalidCoda() {
        // opt + o -> opto (no change because pt is not a valid coda)
        var result: [Character] = ["o", "p", "t"]
        XCTAssertFalse(processor.tryApplyDiacritic("o", to: &result))
        XCTAssertEqual(String(result), "opt") // wait, if not consumed, it'll be opt
    }
}
