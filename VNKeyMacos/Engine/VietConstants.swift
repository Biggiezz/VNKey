// VietConstants.swift
// VNKey — Vietnamese Input Method for macOS
//
// Bảng Unicode ký tự tiếng Việt, enums cốt lõi, và hàm tra cứu.
// Tất cả 134 ký tự nguyên âm có dấu (lowercase + uppercase) + đ/Đ
// được mã hóa trong bảng 3 chiều: [baseVowel][diacritic][tone].

import Foundation

// MARK: - Core Enums

/// Sáu thanh điệu tiếng Việt.
/// Raw value được dùng làm index trong bảng tra cứu ký tự.
enum Tone: Int, CaseIterable, Sendable {
    case none  = 0  // Thanh ngang (không dấu)
    case sac   = 1  // Thanh sắc   (´)  — á
    case huyen = 2  // Thanh huyền (`)  — à
    case hoi   = 3  // Thanh hỏi   (ˀ)  — ả
    case nga   = 4  // Thanh ngã   (~)  — ã
    case nang  = 5  // Thanh nặng  (.)  — ạ
}

/// Dấu phụ (diacritical mark) trên nguyên âm.
enum Diacritic: Int, CaseIterable, Sendable {
    case none       = 0  // Không dấu phụ      — a, e, o, u
    case circumflex = 1  // Dấu mũ (^)         — â, ê, ô
    case breve      = 2  // Dấu trăng (˘)      — ă
    case horn       = 3  // Dấu móc (ˀ)        — ơ, ư
}

enum InputMethod: String, CaseIterable, Sendable {
    case telex       = "telex"
    case vni         = "vni"
    case simpleTelex = "simpleTelex"
}

// MARK: - Vowel Decomposition Result

/// Kết quả phân tích một ký tự nguyên âm tiếng Việt.
struct VowelDecomposition: Equatable, Sendable {
    let base: Character       // Nguyên âm gốc: a, e, i, o, u, y
    let diacritic: Diacritic  // Dấu phụ hiện tại
    let tone: Tone            // Thanh điệu hiện tại
    let isUppercase: Bool     // Có phải chữ hoa không
}

// MARK: - VietConstants

/// Namespace chứa tất cả hằng số và bảng tra cứu tiếng Việt.
enum VietConstants {

    // MARK: Base Vowel Index Mapping

    /// Map nguyên âm gốc (lowercase) → index trong bảng.
    /// a=0, e=1, i=2, o=3, u=4, y=5
    static let baseVowelIndices: [Character: Int] = [
        "a": 0, "e": 1, "i": 2, "o": 3, "u": 4, "y": 5
    ]

    /// Map ngược: index → nguyên âm gốc.
    static let indexToBaseVowel: [Character] = ["a", "e", "i", "o", "u", "y"]

    // MARK: - Vowel Character Table (Lowercase)

    /// Bảng ký tự nguyên âm tiếng Việt 3 chiều: [base][diacritic][tone]
    ///
    /// - Dimension 1: base vowel (a=0, e=1, i=2, o=3, u=4, y=5)
    /// - Dimension 2: diacritic (none=0, circumflex=1, breve=2, horn=3)
    /// - Dimension 3: tone (none=0, sắc=1, huyền=2, hỏi=3, ngã=4, nặng=5)
    ///
    /// Mảng rỗng [] = tổ hợp không hợp lệ (vd: a + horn, e + breve).
    static let vowelTable: [[[Character]]] = [
        // ── a ──
        [
            // none:       a    á    à    ả    ã    ạ
            ["\u{0061}", "\u{00E1}", "\u{00E0}", "\u{1EA3}", "\u{00E3}", "\u{1EA1}"],
            // circumflex: â    ấ    ầ    ẩ    ẫ    ậ
            ["\u{00E2}", "\u{1EA5}", "\u{1EA7}", "\u{1EA9}", "\u{1EAB}", "\u{1EAD}"],
            // breve:      ă    ắ    ằ    ẳ    ẵ    ặ
            ["\u{0103}", "\u{1EAF}", "\u{1EB1}", "\u{1EB3}", "\u{1EB5}", "\u{1EB7}"],
            // horn:       (invalid for 'a')
            [],
        ],
        // ── e ──
        [
            // none:       e    é    è    ẻ    ẽ    ẹ
            ["\u{0065}", "\u{00E9}", "\u{00E8}", "\u{1EBB}", "\u{1EBD}", "\u{1EB9}"],
            // circumflex: ê    ế    ề    ể    ễ    ệ
            ["\u{00EA}", "\u{1EBF}", "\u{1EC1}", "\u{1EC3}", "\u{1EC5}", "\u{1EC7}"],
            // breve:      (invalid for 'e')
            [],
            // horn:       (invalid for 'e')
            [],
        ],
        // ── i ──
        [
            // none:       i    í    ì    ỉ    ĩ    ị
            ["\u{0069}", "\u{00ED}", "\u{00EC}", "\u{1EC9}", "\u{0129}", "\u{1ECB}"],
            // circumflex: (invalid for 'i')
            [],
            // breve:      (invalid for 'i')
            [],
            // horn:       (invalid for 'i')
            [],
        ],
        // ── o ──
        [
            // none:       o    ó    ò    ỏ    õ    ọ
            ["\u{006F}", "\u{00F3}", "\u{00F2}", "\u{1ECF}", "\u{00F5}", "\u{1ECD}"],
            // circumflex: ô    ố    ồ    ổ    ỗ    ộ
            ["\u{00F4}", "\u{1ED1}", "\u{1ED3}", "\u{1ED5}", "\u{1ED7}", "\u{1ED9}"],
            // breve:      (invalid for 'o')
            [],
            // horn:       ơ    ớ    ờ    ở    ỡ    ợ
            ["\u{01A1}", "\u{1EDB}", "\u{1EDD}", "\u{1EDF}", "\u{1EE1}", "\u{1EE3}"],
        ],
        // ── u ──
        [
            // none:       u    ú    ù    ủ    ũ    ụ
            ["\u{0075}", "\u{00FA}", "\u{00F9}", "\u{1EE7}", "\u{0169}", "\u{1EE5}"],
            // circumflex: (invalid for 'u')
            [],
            // breve:      (invalid for 'u')
            [],
            // horn:       ư    ứ    ừ    ử    ữ    ự
            ["\u{01B0}", "\u{1EE9}", "\u{1EEB}", "\u{1EED}", "\u{1EEF}", "\u{1EF1}"],
        ],
        // ── y ──
        [
            // none:       y    ý    ỳ    ỷ    ỹ    ỵ
            ["\u{0079}", "\u{00FD}", "\u{1EF3}", "\u{1EF7}", "\u{1EF9}", "\u{1EF5}"],
            // circumflex: (invalid for 'y')
            [],
            // breve:      (invalid for 'y')
            [],
            // horn:       (invalid for 'y')
            [],
        ],
    ]

    // MARK: - Precomputed Reverse Lookup

    /// Bảng tra ngược: ký tự nguyên âm → VowelDecomposition.
    /// Được tạo 1 lần khi app khởi động. Thread-safe vì là let.
    static let decomposeTable: [Character: VowelDecomposition] = {
        var table: [Character: VowelDecomposition] = [:]
        for (baseIdx, base) in indexToBaseVowel.enumerated() {
            for diacriticCase in Diacritic.allCases {
                let dIdx = diacriticCase.rawValue
                guard dIdx < vowelTable[baseIdx].count,
                      !vowelTable[baseIdx][dIdx].isEmpty else { continue }
                for toneCase in Tone.allCases {
                    let tIdx = toneCase.rawValue
                    let ch = vowelTable[baseIdx][dIdx][tIdx]
                    // Lowercase
                    table[ch] = VowelDecomposition(
                        base: base, diacritic: diacriticCase,
                        tone: toneCase, isUppercase: false
                    )
                    // Uppercase
                    let upper = Character(ch.uppercased())
                    if upper != ch {
                        table[upper] = VowelDecomposition(
                            base: base, diacritic: diacriticCase,
                            tone: toneCase, isUppercase: true
                        )
                    }
                }
            }
        }
        return table
    }()

    // MARK: - Compose / Decompose

    /// Tổng hợp ký tự nguyên âm từ (base, diacritic, tone).
    /// Tự động xử lý uppercase nếu `uppercase = true`.
    static func compose(
        base: Character,
        diacritic: Diacritic,
        tone: Tone,
        uppercase: Bool = false
    ) -> Character? {
        let lowerBase = Character(base.lowercased())
        guard let baseIdx = baseVowelIndices[lowerBase] else { return nil }
        let dIdx = diacritic.rawValue
        guard dIdx < vowelTable[baseIdx].count,
              !vowelTable[baseIdx][dIdx].isEmpty else { return nil }
        let tIdx = tone.rawValue
        let ch = vowelTable[baseIdx][dIdx][tIdx]
        return uppercase ? Character(ch.uppercased()) : ch
    }

    /// Phân tích một ký tự nguyên âm tiếng Việt thành (base, diacritic, tone).
    static func decompose(_ char: Character) -> VowelDecomposition? {
        return decomposeTable[char]
    }

    // MARK: - Character Classification

    /// Tập hợp nguyên âm gốc (lowercase).
    static let baseVowels: Set<Character> = Set(["a", "e", "i", "o", "u", "y"])

    /// Kiểm tra ký tự có phải nguyên âm tiếng Việt (bao gồm có dấu) không.
    static func isVowel(_ char: Character) -> Bool {
        return decomposeTable[char] != nil || baseVowels.contains(Character(char.lowercased()))
    }

    /// Kiểm tra ký tự có phải phụ âm tiếng Việt không.
    static func isConsonant(_ char: Character) -> Bool {
        let lower = Character(char.lowercased())
        return lower.isLetter && !isVowel(char) && lower != "đ"
    }

    /// Kiểm tra có phải chữ cái Latin (bao gồm ký tự VN có dấu).
    static func isLetter(_ char: Character) -> Bool {
        return char.isLetter || decomposeTable[char] != nil
    }

    // MARK: - Vietnamese Consonant Sets

    /// Phụ âm đầu hợp lệ trong tiếng Việt.
    static let validOnsets: Set<String> = [
        "b", "c", "ch", "d", "g", "gh", "gi", "h", "k", "kh",
        "l", "m", "n", "ng", "ngh", "nh", "p", "ph", "qu",
        "r", "s", "t", "th", "tr", "v", "x",
        // đ is special — handled separately
    ]

    /// Phụ âm cuối hợp lệ trong tiếng Việt.
    static let validCodas: Set<String> = [
        "c", "ch", "m", "n", "ng", "nh", "p", "t",
    ]

    /// Các ký tự không bao giờ là tone key / diacritic modifier khi đứng ở
    /// đầu syllable (trước mọi nguyên âm).
    static let consonantOnlyChars: Set<Character> = [
        "b", "c", "g", "h", "k", "l", "m", "n", "p", "q",
        "t", "v",
    ]

    // MARK: - Telex Key Mappings

    /// Telex: Tone keys. Chỉ áp dụng khi đã có nguyên âm trước đó.
    static let telexToneKeys: [Character: Tone] = [
        "s": .sac,    // sắc
        "f": .huyen,  // huyền
        "r": .hoi,    // hỏi
        "x": .nga,    // ngã
        "j": .nang,   // nặng
        "z": .none,   // xóa dấu thanh
    ]

    /// Telex: Diacritic triggers. Key = ký tự trigger, Value = (nguyên âm đích, dấu phụ).
    /// Ví dụ: 'w' sau 'a' → ă, 'w' sau 'o' → ơ, 'w' sau 'u' → ư
    static let telexDiacriticW: [Character: Diacritic] = [
        "a": .breve,       // aw → ă
        "o": .horn,        // ow → ơ
        "u": .horn,        // uw → ư
    ]

    /// Telex: Double-press diacritics. 'aa' → â, 'ee' → ê, 'oo' → ô
    static let telexDoublePressDiacritics: [Character: Diacritic] = [
        "a": .circumflex,  // aa → â
        "e": .circumflex,  // ee → ê
        "o": .circumflex,  // oo → ô
    ]

    // MARK: - VNI Key Mappings

    /// VNI: Tone keys (số 1-5, 0 xóa dấu).
    static let vniToneKeys: [Character: Tone] = [
        "1": .sac,
        "2": .huyen,
        "3": .hoi,
        "4": .nga,
        "5": .nang,
        "0": .none,   // xóa dấu thanh
    ]

    /// VNI: Diacritic keys (số 6-9).
    /// 6 → circumflex (cho a, e, o): â, ê, ô
    /// 7 → horn (cho o, u): ơ, ư
    /// 8 → breve (cho a): ă
    /// 9 → đ
    static let vniDiacriticKeys: [Character: [(target: Character, diacritic: Diacritic)]] = [
        "6": [("a", .circumflex), ("e", .circumflex), ("o", .circumflex)],
        "7": [("o", .horn), ("u", .horn)],
        "8": [("a", .breve)],
    ]

    // MARK: - Đ / đ Handling

    /// Kiểm tra ký tự có phải đ/Đ không.
    static func isDBar(_ char: Character) -> Bool {
        return char == "\u{0111}" || char == "\u{0110}"
    }

    /// Chuyển d → đ (hoặc D → Đ). Trả về nil nếu input không phải d/D.
    static func toDBar(_ char: Character) -> Character? {
        switch char {
        case "d": return "\u{0111}"  // đ
        case "D": return "\u{0110}"  // Đ
        default: return nil
        }
    }

    /// Chuyển đ → d (hoặc Đ → D). Trả về nil nếu input không phải đ/Đ.
    static func fromDBar(_ char: Character) -> Character? {
        switch char {
        case "\u{0111}": return "d"
        case "\u{0110}": return "D"
        default: return nil
        }
    }
}
