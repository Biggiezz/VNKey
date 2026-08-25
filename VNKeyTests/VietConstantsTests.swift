// VietConstantsTests.swift
// VNKeyTests
//
// Unit tests cho VietConstants — bảng Unicode và hàm tra cứu.

import XCTest
@testable import VNKey

final class VietConstantsTests: XCTestCase {

    // MARK: - Compose Tests

    func testComposeBasicVowels() {
        // a + none + sắc = á
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .none, tone: .sac), "á")
        // a + none + huyền = à
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .none, tone: .huyen), "à")
        // a + none + hỏi = ả
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .none, tone: .hoi), "ả")
        // a + none + ngã = ã
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .none, tone: .nga), "ã")
        // a + none + nặng = ạ
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .none, tone: .nang), "ạ")
    }

    func testComposeCircumflex() {
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .circumflex, tone: .none), "â")
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .circumflex, tone: .sac), "ấ")
        XCTAssertEqual(VietConstants.compose(base: "e", diacritic: .circumflex, tone: .none), "ê")
        XCTAssertEqual(VietConstants.compose(base: "e", diacritic: .circumflex, tone: .nang), "ệ")
        XCTAssertEqual(VietConstants.compose(base: "o", diacritic: .circumflex, tone: .none), "ô")
    }

    func testComposeBreve() {
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .breve, tone: .none), "ă")
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .breve, tone: .sac), "ắ")
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .breve, tone: .nang), "ặ")
    }

    func testComposeHorn() {
        XCTAssertEqual(VietConstants.compose(base: "o", diacritic: .horn, tone: .none), "ơ")
        XCTAssertEqual(VietConstants.compose(base: "o", diacritic: .horn, tone: .sac), "ớ")
        XCTAssertEqual(VietConstants.compose(base: "u", diacritic: .horn, tone: .none), "ư")
        XCTAssertEqual(VietConstants.compose(base: "u", diacritic: .horn, tone: .huyen), "ừ")
    }

    func testComposeUppercase() {
        XCTAssertEqual(VietConstants.compose(base: "a", diacritic: .none, tone: .sac, uppercase: true), "Á")
        XCTAssertEqual(VietConstants.compose(base: "e", diacritic: .circumflex, tone: .sac, uppercase: true), "Ế")
        XCTAssertEqual(VietConstants.compose(base: "o", diacritic: .horn, tone: .none, uppercase: true), "Ơ")
    }

    func testComposeInvalidCombinations() {
        // a + horn is invalid
        XCTAssertNil(VietConstants.compose(base: "a", diacritic: .horn, tone: .none))
        // e + breve is invalid
        XCTAssertNil(VietConstants.compose(base: "e", diacritic: .breve, tone: .none))
        // i + circumflex is invalid
        XCTAssertNil(VietConstants.compose(base: "i", diacritic: .circumflex, tone: .none))
        // non-vowel base
        XCTAssertNil(VietConstants.compose(base: "b", diacritic: .none, tone: .sac))
    }

    // MARK: - Decompose Tests

    func testDecomposeBasicVowels() {
        let result = VietConstants.decompose("á")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.base, "a")
        XCTAssertEqual(result?.diacritic, Diacritic.none)
        XCTAssertEqual(result?.tone, Tone.sac)
        XCTAssertEqual(result?.isUppercase, false)
    }

    func testDecomposeComplex() {
        // ệ = e + circumflex + nặng
        let result = VietConstants.decompose("ệ")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.base, "e")
        XCTAssertEqual(result?.diacritic, .circumflex)
        XCTAssertEqual(result?.tone, .nang)
    }

    func testDecomposeUppercase() {
        let result = VietConstants.decompose("Ấ")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.base, "a")
        XCTAssertEqual(result?.diacritic, .circumflex)
        XCTAssertEqual(result?.tone, .sac)
        XCTAssertEqual(result?.isUppercase, true)
    }

    func testDecomposeNonVietnamese() {
        XCTAssertNil(VietConstants.decompose("b"))
        XCTAssertNil(VietConstants.decompose("1"))
        XCTAssertNil(VietConstants.decompose("@"))
    }

    // MARK: - Roundtrip Tests

    func testComposeDecomposeRoundtrip() {
        // Compose then decompose should return original components
        for baseCase in Diacritic.allCases {
            for toneCase in Tone.allCases {
                if let composed = VietConstants.compose(base: "a", diacritic: baseCase, tone: toneCase) {
                    let decomposed = VietConstants.decompose(composed)
                    XCTAssertNotNil(decomposed, "Failed to decompose \(composed)")
                    XCTAssertEqual(decomposed?.base, "a")
                    XCTAssertEqual(decomposed?.diacritic, baseCase)
                    XCTAssertEqual(decomposed?.tone, toneCase)
                }
            }
        }
    }

    // MARK: - Character Classification

    func testIsVowel() {
        // Basic vowels
        XCTAssertTrue(VietConstants.isVowel("a"))
        XCTAssertTrue(VietConstants.isVowel("e"))
        XCTAssertTrue(VietConstants.isVowel("i"))
        XCTAssertTrue(VietConstants.isVowel("o"))
        XCTAssertTrue(VietConstants.isVowel("u"))
        XCTAssertTrue(VietConstants.isVowel("y"))

        // Vietnamese vowels with diacritics
        XCTAssertTrue(VietConstants.isVowel("ă"))
        XCTAssertTrue(VietConstants.isVowel("â"))
        XCTAssertTrue(VietConstants.isVowel("ê"))
        XCTAssertTrue(VietConstants.isVowel("ơ"))
        XCTAssertTrue(VietConstants.isVowel("ư"))

        // Vietnamese vowels with tones
        XCTAssertTrue(VietConstants.isVowel("á"))
        XCTAssertTrue(VietConstants.isVowel("ệ"))
        XCTAssertTrue(VietConstants.isVowel("ự"))

        // Uppercase
        XCTAssertTrue(VietConstants.isVowel("A"))
        XCTAssertTrue(VietConstants.isVowel("Ấ"))

        // Not vowels
        XCTAssertFalse(VietConstants.isVowel("b"))
        XCTAssertFalse(VietConstants.isVowel("c"))
        XCTAssertFalse(VietConstants.isVowel("1"))
    }

    // MARK: - D-bar Tests

    func testDBar() {
        XCTAssertEqual(VietConstants.toDBar("d"), "\u{0111}")  // đ
        XCTAssertEqual(VietConstants.toDBar("D"), "\u{0110}")  // Đ
        XCTAssertNil(VietConstants.toDBar("a"))

        XCTAssertEqual(VietConstants.fromDBar("\u{0111}"), "d")
        XCTAssertEqual(VietConstants.fromDBar("\u{0110}"), "D")
        XCTAssertNil(VietConstants.fromDBar("d"))

        XCTAssertTrue(VietConstants.isDBar("\u{0111}"))
        XCTAssertTrue(VietConstants.isDBar("\u{0110}"))
        XCTAssertFalse(VietConstants.isDBar("d"))
    }
}
