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
        // 'w' sau 'e' → không match với e, và vì từ đã có nguyên âm nên 'w' giữ nguyên là chữ 'w'
        var result: [Character] = ["e"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &result))
        XCTAssertEqual(String(result), "e")
        XCTAssertEqual(applyDiacritic("w", to: "e"), "ew")
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
        XCTAssertEqual(String(result), "opt")
    }

    func testWAfterInvalidCodaNotApplied() {
        // "pass" + "w" -> KHÔNG được biến "a" thành "ă" vì "ss" không phải coda tiếng Việt
        var resultPass: [Character] = ["p", "a", "s", "s"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultPass))
        XCTAssertEqual(String(resultPass), "pass")
        XCTAssertEqual(applyDiacritic("w", to: "pass"), "passw")

        // "fast" + "w" -> không biến "a" thành "ă" vì "st" không phải coda
        var resultFast: [Character] = ["f", "a", "s", "t"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultFast))
        XCTAssertEqual(String(resultFast), "fast")

        // "task" + "w" -> không biến "a" thành "ă" vì "sk" không phải coda
        var resultTask: [Character] = ["t", "a", "s", "k"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultTask))
        XCTAssertEqual(String(resultTask), "task")

        // "hard" + "w" -> không biến "a" thành "ă" vì "rd" không phải coda
        var resultHard: [Character] = ["h", "a", "r", "d"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultHard))
        XCTAssertEqual(String(resultHard), "hard")

        // "card" + "w" -> không biến "a" thành "ă" vì "rd" không phải coda
        var resultCard: [Character] = ["c", "a", "r", "d"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultCard))
        XCTAssertEqual(String(resultCard), "card")

        // "cost" + "w" -> không biến "o" thành "ơ" vì "st" không phải coda
        var resultCost: [Character] = ["c", "o", "s", "t"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultCost))
        XCTAssertEqual(String(resultCost), "cost")
    }

    func testWAfterInvalidOnsetNotApplied() {
        // "dra" + "w" -> onset "dr" không hợp lệ tiếng Việt -> giữ nguyên "draw"
        var resultDraw: [Character] = ["d", "r", "a"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultDraw))
        XCTAssertEqual(String(resultDraw), "dra")
        XCTAssertEqual(applyDiacritic("w", to: "dra"), "draw")

        // "slo" + "w" -> onset "sl" không hợp lệ -> "slow"
        var resultSlow: [Character] = ["s", "l", "o"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultSlow))
        XCTAssertEqual(String(resultSlow), "slo")
        XCTAssertEqual(applyDiacritic("w", to: "slo"), "slow")

        // "flo" + "w" -> onset "fl" không hợp lệ -> "flow"
        var resultFlow: [Character] = ["f", "l", "o"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultFlow))
        XCTAssertEqual(String(resultFlow), "flo")
        XCTAssertEqual(applyDiacritic("w", to: "flo"), "flow")

        // "blo" + "w" -> onset "bl" không hợp lệ -> "blow"
        var resultBlow: [Character] = ["b", "l", "o"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultBlow))
        XCTAssertEqual(String(resultBlow), "blo")
        XCTAssertEqual(applyDiacritic("w", to: "blo"), "blow")

        // "stra" + "w" -> onset "str" không hợp lệ -> "straw"
        var resultStraw: [Character] = ["s", "t", "r", "a"]
        XCTAssertFalse(processor.tryApplyDiacritic("w", to: &resultStraw))
        XCTAssertEqual(String(resultStraw), "stra")
        XCTAssertEqual(applyDiacritic("w", to: "stra"), "straw")
    }

    func testDoublePressMultiSyllableWord() {
        // "banana" -> double-press 'a' sau "banan" không được biến thành "banân"
        var resultBanana: [Character] = ["b", "a", "n", "a", "n"]
        XCTAssertFalse(processor.tryApplyDiacritic("a", to: &resultBanana))
        XCTAssertEqual(String(resultBanana), "banan")

        // "delete" -> double-press 'e' sau "delet" không được biến thành "delête"
        var resultDelete: [Character] = ["d", "e", "l", "e", "t"]
        XCTAssertFalse(processor.tryApplyDiacritic("e", to: &resultDelete))
        XCTAssertEqual(String(resultDelete), "delet")
    }

    func testDBarDoesNotCorruptLongWords() {
        // "download" -> khi gõ chữ 'd' cuối cùng, không được biến chữ 'd' đầu tiên thành 'đ'
        var resultDownload: [Character] = ["d", "o", "w", "n", "l", "o", "a"]
        XCTAssertFalse(processor.tryApplyDiacritic("d", to: &resultDownload))
        XCTAssertEqual(String(resultDownload), "downloa")

        // "dashboard" -> không được biến chữ 'd' đầu tiên thành 'đ'
        var resultDashboard: [Character] = ["d", "a", "s", "h", "b", "o", "a", "r"]
        XCTAssertFalse(processor.tryApplyDiacritic("d", to: &resultDashboard))
        XCTAssertEqual(String(resultDashboard), "dashboar")
    }
}
