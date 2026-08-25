// VNIProcessorTests.swift
// VNKeyTests
//
// Unit tests cho VNIProcessor — kiểu gõ VNI.

import XCTest
@testable import VNKey

final class VNIProcessorTests: XCTestCase {

    let processor = VNIProcessor()

    // MARK: - Diacritic Key 6 (Circumflex: â, ê, ô)

    func testKey6OnA() {
        var result: [Character] = ["a"]
        XCTAssertTrue(processor.tryApplyDiacritic("6", to: &result))
        XCTAssertEqual(String(result), "â")
    }

    func testKey6OnE() {
        var result: [Character] = ["e"]
        XCTAssertTrue(processor.tryApplyDiacritic("6", to: &result))
        XCTAssertEqual(String(result), "ê")
    }

    func testKey6OnO() {
        var result: [Character] = ["o"]
        XCTAssertTrue(processor.tryApplyDiacritic("6", to: &result))
        XCTAssertEqual(String(result), "ô")
    }

    func testKey6OnInvalidVowel() {
        // 'u' không nhận key 6
        var result: [Character] = ["u"]
        XCTAssertFalse(processor.tryApplyDiacritic("6", to: &result))
        XCTAssertEqual(String(result), "u")
    }

    func testKey6Undo() {
        // â + 6 → a6 (undo)
        var result: [Character] = ["â"]
        XCTAssertTrue(processor.tryApplyDiacritic("6", to: &result))
        XCTAssertEqual(String(result), "a6")
    }

    // MARK: - Diacritic Key 7 (Horn: ơ, ư)

    func testKey7OnO() {
        var result: [Character] = ["o"]
        XCTAssertTrue(processor.tryApplyDiacritic("7", to: &result))
        XCTAssertEqual(String(result), "ơ")
    }

    func testKey7OnU() {
        var result: [Character] = ["u"]
        XCTAssertTrue(processor.tryApplyDiacritic("7", to: &result))
        XCTAssertEqual(String(result), "ư")
    }

    func testKey7OnInvalidVowel() {
        var result: [Character] = ["a"]
        XCTAssertFalse(processor.tryApplyDiacritic("7", to: &result))
    }

    // MARK: - Diacritic Key 8 (Breve: ă)

    func testKey8OnA() {
        var result: [Character] = ["a"]
        XCTAssertTrue(processor.tryApplyDiacritic("8", to: &result))
        XCTAssertEqual(String(result), "ă")
    }

    func testKey8OnInvalidVowel() {
        var result: [Character] = ["e"]
        XCTAssertFalse(processor.tryApplyDiacritic("8", to: &result))
    }

    // MARK: - Diacritic Key 9 (đ)

    func testKey9OnD() {
        var result: [Character] = ["d"]
        XCTAssertTrue(processor.tryApplyDiacritic("9", to: &result))
        XCTAssertEqual(String(result), "đ")
    }

    func testKey9OnUpperD() {
        var result: [Character] = ["D"]
        XCTAssertTrue(processor.tryApplyDiacritic("9", to: &result))
        XCTAssertEqual(String(result), "Đ")
    }

    func testKey9Undo() {
        // đ + 9 → d9 (undo)
        var result: [Character] = ["đ"]
        XCTAssertTrue(processor.tryApplyDiacritic("9", to: &result))
        XCTAssertEqual(String(result), "d9")
    }

    // MARK: - Tone Keys

    func testVNIToneKeys() {
        XCTAssertEqual(processor.toneForKey("1"), Tone.sac)
        XCTAssertEqual(processor.toneForKey("2"), Tone.huyen)
        XCTAssertEqual(processor.toneForKey("3"), Tone.hoi)
        XCTAssertEqual(processor.toneForKey("4"), Tone.nga)
        XCTAssertEqual(processor.toneForKey("5"), Tone.nang)
        XCTAssertEqual(processor.toneForKey("0"), Tone.none)
    }

    func testNonToneKeys() {
        XCTAssertNil(processor.toneForKey("a"))
        XCTAssertNil(processor.toneForKey("s"))
        XCTAssertNil(processor.toneForKey("6"))  // 6 is diacritic, not tone
    }

    // MARK: - Context Tests

    func testDiacriticInWord() {
        // "vi" + "e" thì key 6 → "viê"
        var result: [Character] = ["v", "i", "e"]
        XCTAssertTrue(processor.tryApplyDiacritic("6", to: &result))
        XCTAssertEqual(String(result), "viê")
    }

    func testKey7InWord() {
        // "thu" + 7 → "thư"
        var result: [Character] = ["t", "h", "u"]
        XCTAssertTrue(processor.tryApplyDiacritic("7", to: &result))
        XCTAssertEqual(String(result), "thư")
    }

    func testDoubleHornRule() {
        // "uo" + 7 -> "ươ"
        var result: [Character] = ["u", "o"]
        XCTAssertTrue(processor.tryApplyDiacritic("7", to: &result))
        XCTAssertEqual(String(result), "ươ")
    }
}
