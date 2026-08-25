// ToneManagerTests.swift
// VNKeyTests
//
// Unit tests cho ToneManager — đặt dấu thanh.

import XCTest
@testable import VNKey

final class ToneManagerTests: XCTestCase {

    let toneManager = ToneManager()

    // MARK: - Apply Tone to Single Char

    func testApplyToneToChar() {
        XCTAssertEqual(toneManager.applyToneToChar("a", tone: .sac), "á")
        XCTAssertEqual(toneManager.applyToneToChar("a", tone: .huyen), "à")
        XCTAssertEqual(toneManager.applyToneToChar("a", tone: .hoi), "ả")
        XCTAssertEqual(toneManager.applyToneToChar("a", tone: .nga), "ã")
        XCTAssertEqual(toneManager.applyToneToChar("a", tone: .nang), "ạ")
    }

    func testApplyToneToCharWithDiacritic() {
        XCTAssertEqual(toneManager.applyToneToChar("â", tone: .sac), "ấ")
        XCTAssertEqual(toneManager.applyToneToChar("ê", tone: .nang), "ệ")
        XCTAssertEqual(toneManager.applyToneToChar("ơ", tone: .huyen), "ờ")
        XCTAssertEqual(toneManager.applyToneToChar("ư", tone: .nga), "ữ")
    }

    func testApplyToneToUppercase() {
        XCTAssertEqual(toneManager.applyToneToChar("A", tone: .sac), "Á")
        XCTAssertEqual(toneManager.applyToneToChar("Ê", tone: .sac), "Ế")
    }

    func testApplyToneToNonVowel() {
        XCTAssertNil(toneManager.applyToneToChar("b", tone: .sac))
        XCTAssertNil(toneManager.applyToneToChar("1", tone: .sac))
    }

    // MARK: - Remove Tone

    func testRemoveTone() {
        let input: [Character] = ["v", "i", "ệ", "t"]
        let result = toneManager.removeTone(from: input)
        XCTAssertEqual(String(result), "viêt")
    }

    func testRemoveToneKeepsDiacritics() {
        // Xóa dấu nặng nhưng giữ dấu mũ (ê)
        let input: [Character] = ["ệ"]
        let result = toneManager.removeTone(from: input)
        XCTAssertEqual(String(result), "ê")
    }

    func testRemoveToneNoChange() {
        // Không có dấu thanh → không đổi
        let input: [Character] = ["v", "i", "ê", "t"]
        let result = toneManager.removeTone(from: input)
        XCTAssertEqual(String(result), "viêt")
    }

    // MARK: - Tone Placement (Old Style)

    func testTonePlacementSingleVowel() {
        // "ba" + sắc → "bá"
        let input: [Character] = ["b", "a"]
        let result = toneManager.applyTone(to: input, tone: .sac, style: .oldStyle)
        XCTAssertEqual(String(result), "bá")
    }

    func testTonePlacementWithDiacritic() {
        // "bâ" + sắc → "bấ" (ưu tiên nguyên âm có dấu phụ)
        let input: [Character] = ["b", "â"]
        let result = toneManager.applyTone(to: input, tone: .sac, style: .oldStyle)
        XCTAssertEqual(String(result), "bấ")
    }

    func testTonePlacementTwoVowelsWithCoda() {
        // "oat" → 2 nguyên âm + phụ âm cuối → dấu lên nguyên âm thứ 2
        let input: [Character] = ["o", "a", "t"]
        let result = toneManager.applyTone(to: input, tone: .sac, style: .oldStyle)
        XCTAssertEqual(String(result), "oát")
    }

    func testTonePlacementTwoVowelsNoCoda() {
        // "oa" → 2 nguyên âm, không phụ âm cuối → dấu lên nguyên âm thứ 1
        let input: [Character] = ["o", "a"]
        let result = toneManager.applyTone(to: input, tone: .sac, style: .oldStyle)
        XCTAssertEqual(String(result), "óa")
    }

    func testTonePlacementThreeVowels() {
        // "oai" → 3 nguyên âm → dấu lên nguyên âm thứ 2
        let input: [Character] = ["o", "a", "i"]
        let result = toneManager.applyTone(to: input, tone: .sac, style: .oldStyle)
        XCTAssertEqual(String(result), "oái")
    }

    func testTonePlacementRemove() {
        // Áp dụng tone .none → xóa dấu
        let input: [Character] = ["b", "á"]
        let result = toneManager.applyTone(to: input, tone: .none, style: .oldStyle)
        XCTAssertEqual(String(result), "ba")
    }

    // MARK: - Tone Placement (New Style)

    func testTonePlacementNewStyleTwoVowelsNoCoda() {
        // "oa" → new style: dấu lên nguyên âm cuối
        let input: [Character] = ["o", "a"]
        let result = toneManager.applyTone(to: input, tone: .sac, style: .newStyle)
        XCTAssertEqual(String(result), "oá")
    }

    // MARK: - Current Tone

    func testCurrentTone() {
        XCTAssertEqual(toneManager.currentTone(of: "á"), .sac)
        XCTAssertEqual(toneManager.currentTone(of: "à"), .huyen)
        XCTAssertEqual(toneManager.currentTone(of: "ệ"), .nang)
        XCTAssertEqual(toneManager.currentTone(of: "a"), .none)
        XCTAssertEqual(toneManager.currentTone(of: "b"), .none)
    }
}
