// TelexProcessor.swift
// VNKey — Vietnamese Input Method for macOS
//
// Xử lý kiểu gõ Telex.
// Quy tắc Telex:
//   Diacritics: aa→â, ee→ê, oo→ô, aw→ă, ow→ơ, uw→ư, dd→đ
//   Tones: s=sắc, f=huyền, r=hỏi, x=ngã, j=nặng, z=xóa dấu
//   Undo: gõ lại cùng phím modifier → undo (vd: aas → as)

import Foundation

// MARK: - InputMethodProcessor Protocol

/// Protocol chung cho các bộ xử lý kiểu gõ (Telex, VNI).
protocol InputMethodProcessor: Sendable {
    /// Kiểm tra ký tự có phải tone key không (trong ngữ cảnh có nguyên âm).
    func isToneKey(_ char: Character) -> Bool

    /// Lấy Tone tương ứng với ký tự.
    func toneForKey(_ char: Character) -> Tone?

    /// Kiểm tra và áp dụng diacritic transformation.
    /// Trả về true nếu ký tự đã được xử lý (consumed).
    ///
    /// - Parameters:
    ///   - char: Ký tự vừa gõ.
    ///   - result: Mảng ký tự đầu ra (in-out, sẽ bị modify).
    /// - Returns: `true` nếu ký tự được xử lý như diacritic modifier.
    func tryApplyDiacritic(_ char: Character, to result: inout [Character], rawInput: [Character], currentIndex: Int) -> Bool

    /// Kiểm tra ký tự đ/Đ trigger (dd → đ).
    func isDBarTrigger(_ char: Character, previous: Character?) -> Bool
}

// MARK: - TelexProcessor

final class TelexProcessor: InputMethodProcessor {

    // MARK: Tone Key

    func isToneKey(_ char: Character) -> Bool {
        return VietConstants.telexToneKeys[Character(char.lowercased())] != nil
    }

    func toneForKey(_ char: Character) -> Tone? {
        return VietConstants.telexToneKeys[Character(char.lowercased())]
    }

    // MARK: D-Bar (dd → đ)

    func isDBarTrigger(_ char: Character, previous: Character?) -> Bool {
        let lower = Character(char.lowercased())
        guard lower == "d" else { return false }
        guard let prev = previous else { return false }
        return prev == "d" || prev == "D"
    }

    // MARK: Diacritic Application

    func tryApplyDiacritic(_ char: Character, to result: inout [Character], rawInput: [Character], currentIndex: Int) -> Bool {
        let lower = Character(char.lowercased())

        // ── Case 1: dd → đ ──
        if lower == "d" {
            guard !result.isEmpty else { return false }
            
            // Tìm ký tự 'd' hoặc 'đ' ở đầu từ (result[0])
            let firstChar = result[0]
            let firstLower = Character(firstChar.lowercased())
            
            if firstLower == "d" {
                // Biến đổi d/D ở đầu -> đ/Đ
                let isUpper = firstChar.isUppercase
                result[0] = isUpper ? "\u{0110}" : "\u{0111}"
                return true
            } else if VietConstants.isDBar(firstChar) {
                // Undo đ/Đ ở đầu -> d/D và thêm 'd' thô ở cuối
                let isUpper = firstChar == "\u{0110}"
                result[0] = isUpper ? "D" : "d"
                result.append(char)
                return true
            }
            
            // Fallback: nếu d không nằm ở đầu từ, ta biến đổi d ở vị trí cuối cùng (như double press d bình thường)
            if let lastChar = result.last {
                let lastLower = Character(lastChar.lowercased())
                if lastLower == "d" {
                    let isUpper = lastChar.isUppercase
                    result[result.count - 1] = isUpper ? "\u{0110}" : "\u{0111}"
                    return true
                } else if VietConstants.isDBar(lastChar) {
                    let isUpper = lastChar == "\u{0110}"
                    result[result.count - 1] = isUpper ? "D" : "d"
                    result.append(char)
                    return true
                }
            }
            return false
        }

        // ── Case 2: Double-press vowel (aa → â, ee → ê, oo → ô) ──
        if let diacritic = VietConstants.telexDoublePressDiacritics[lower] {
            guard !result.isEmpty else { return false }
            // Tìm nguyên âm cuối cùng cùng loại
            if let lastIdx = findLastMatchingVowel(lower, in: result) {
                let target = result[lastIdx]
                let decomp = VietConstants.decompose(target)
                let targetBase = decomp?.base ?? Character(target.lowercased())
                let targetIsUpper = decomp?.isUppercase ?? target.isUppercase
                let currentDiacritic = decomp?.diacritic ?? .none
                let currentTone = decomp?.tone ?? .none

                if targetBase == lower {
                    if currentDiacritic == diacritic {
                        // Undo: â + a → aa (xóa dấu mũ, thêm ký tự)
                        let plain = VietConstants.compose(
                            base: targetBase, diacritic: .none,
                            tone: currentTone, uppercase: targetIsUpper
                        ) ?? target
                        result[lastIdx] = plain
                        result.append(char)
                        return true
                    } else {
                        // Apply: a + a → â
                        if let composed = VietConstants.compose(
                            base: targetBase, diacritic: diacritic,
                            tone: currentTone, uppercase: targetIsUpper
                        ) {
                            result[lastIdx] = composed
                            return true
                        }
                    }
                }
            }
        }

        // ── Case 3: 'w' modifier (aw → ă, ow → ơ, uw → ư) ──
        if lower == "w" {
            // Tính số lượng chữ 'w' liên tiếp tính đến currentIndex
            var consecutiveWCount = 0
            var idx = currentIndex
            while idx >= 0 && rawInput[idx].lowercased() == "w" {
                consecutiveWCount += 1
                idx -= 1
            }
            
            let isUpper = char.isUppercase
            
            if consecutiveWCount % 2 == 1 {
                // ── Lượt gõ lẻ (1, 3, 5...): tạo dấu ư hoặc ă/ơ/ư kết hợp ──
                if consecutiveWCount == 1 {
                    // Lần đầu gõ 'w', thử kết hợp với nguyên âm trước đó (vd: aw -> ă)
                    if let lastIdx = findLastVowelForW(in: result) {
                        let target = result[lastIdx]
                        let decomp = VietConstants.decompose(target)
                        let targetBase = decomp?.base ?? Character(target.lowercased())
                        let targetIsUpper = decomp?.isUppercase ?? target.isUppercase
                        let currentDiacritic = decomp?.diacritic ?? .none
                        let currentTone = decomp?.tone ?? .none
                        
                        if let newDiacritic = VietConstants.telexDiacriticW[targetBase] {
                            if currentDiacritic == newDiacritic {
                                // Undo: ă + w → aw, ơ + w → ow, ư + w → uw
                                let plain = VietConstants.compose(
                                    base: targetBase, diacritic: .none,
                                    tone: currentTone, uppercase: targetIsUpper
                                ) ?? target
                                result[lastIdx] = plain
                                result.append(isUpper ? "W" : "w")
                                return true
                            } else {
                                if let composed = VietConstants.compose(
                                    base: targetBase, diacritic: newDiacritic,
                                    tone: currentTone, uppercase: targetIsUpper
                                ) {
                                    result[lastIdx] = composed
                                    
                                    // ── Luật dấu móc kép (Double horn rule): uo + w → ươ ──
                                    if targetBase == "o" && lastIdx > 0 {
                                        let prevChar = result[lastIdx - 1]
                                        let decompPrev = VietConstants.decompose(prevChar)
                                        let prevBase = decompPrev?.base ?? Character(prevChar.lowercased())
                                        if prevBase == "u" {
                                            let prevTone = decompPrev?.tone ?? .none
                                            let prevIsUpper = decompPrev?.isUppercase ?? prevChar.isUppercase
                                            if let prevComposed = VietConstants.compose(
                                                base: "u", diacritic: .horn,
                                                tone: prevTone, uppercase: prevIsUpper
                                            ) {
                                                result[lastIdx - 1] = prevComposed
                                            }
                                        }
                                    }
                                    return true
                                }
                            }
                        }
                    }
                }
                
                // Nếu không kết hợp được hoặc là lượt gõ lẻ thứ 3, 5... -> thêm chữ ư/Ư standalone
                result.append(isUpper ? "Ư" : "ư")
                return true
            } else {
                // ── Lượt gõ chẵn (2, 4, 6...): undo hoặc chuyển ư -> w ──
                let firstWIndex = currentIndex - consecutiveWCount + 1
                let isWTargetVowel: Bool
                if firstWIndex > 0 {
                    let prevChar = Character(rawInput[firstWIndex - 1].lowercased())
                    isWTargetVowel = prevChar == "a" || prevChar == "o" || prevChar == "u"
                } else {
                    isWTargetVowel = false
                }
                
                if consecutiveWCount == 2 && isWTargetVowel {
                    // Undo kết hợp nguyên âm trước đó (ă -> aw, ơ -> ow, ư -> uw)
                    if let lastIdx = findLastVowelForW(in: result) {
                        let target = result[lastIdx]
                        let decomp = VietConstants.decompose(target)
                        let targetBase = decomp?.base ?? Character(target.lowercased())
                        let targetIsUpper = decomp?.isUppercase ?? target.isUppercase
                        let currentDiacritic = decomp?.diacritic ?? .none
                        let currentTone = decomp?.tone ?? .none
                        
                        if let newDiacritic = VietConstants.telexDiacriticW[targetBase] {
                            if currentDiacritic == newDiacritic {
                                let plain = VietConstants.compose(
                                    base: targetBase, diacritic: .none,
                                    tone: currentTone, uppercase: targetIsUpper
                                ) ?? target
                                result[lastIdx] = plain
                                result.append(isUpper ? "W" : "w")
                                return true
                            }
                        }
                    }
                }
                
                // Trường hợp còn lại: thay thế chữ ư/Ư cuối cùng bằng w/W
                if let lastChar = result.last, (lastChar == "ư" || lastChar == "Ư") {
                    let lastIsUpper = lastChar == "Ư"
                    result[result.count - 1] = lastIsUpper ? "W" : "w"
                    return true
                }
            }
            return false
        }

        return false
    }

    // MARK: - Private Helpers

    /// Tìm nguyên âm cuối cùng có base vowel khớp (cho double-press).
    private func findLastMatchingVowel(
        _ baseChar: Character,
        in chars: [Character]
    ) -> Int? {
        for i in stride(from: chars.count - 1, through: 0, by: -1) {
            let ch = chars[i]
            
            // Nếu gặp một nguyên âm khác baseChar -> dừng luôn vì đã chuyển sang âm tiết khác/vần khác
            if VietConstants.isVowel(ch) {
                let decomp = VietConstants.decompose(ch)
                let base = decomp?.base ?? Character(ch.lowercased())
                if base != baseChar {
                    break
                }
                
                // Nếu đúng là baseChar, kiểm tra xem suffix có phải là coda hợp lệ không
                let suffix = String(chars[(i + 1)...]).lowercased()
                if suffix.isEmpty || VietConstants.validCodas.contains(suffix) {
                    return i
                }
                break
            }
        }
        return nil
    }

    /// Tìm nguyên âm cuối cùng có thể nhận modifier 'w'.
    /// Chỉ a, o, u mới nhận được 'w'.
    private func findLastVowelForW(in chars: [Character]) -> Int? {
        let wTargets: Set<Character> = ["a", "o", "u"]
        var consonantCount = 0
        
        for i in stride(from: chars.count - 1, through: 0, by: -1) {
            let ch = chars[i]
            
            // Cho phép đi qua tối đa 2 phụ âm cuối của một âm tiết tiếng Việt (ví dụ: c trong 'được', ng trong 'đường')
            if VietConstants.isConsonant(ch) || VietConstants.isDBar(ch) {
                consonantCount += 1
                if consonantCount > 2 {
                    break
                }
                continue
            }
            
            let lower = Character(ch.lowercased())
            let baseChar: Character
            if let decomp = VietConstants.decompose(ch) {
                baseChar = decomp.base
            } else {
                baseChar = lower
            }
            
            if wTargets.contains(baseChar) {
                return i
            } else {
                // Gặp nguyên âm khác (ví dụ: i, e, y) -> nghĩa là đã chuyển sang âm tiết khác, không được kết hợp
                break
            }
        }
        return nil
    }
}

// MARK: - InputMethodProcessor Extension for Backward Compatibility

extension InputMethodProcessor {
    func tryApplyDiacritic(_ char: Character, to result: inout [Character]) -> Bool {
        let rawInput = result + [char]
        return self.tryApplyDiacritic(char, to: &result, rawInput: rawInput, currentIndex: result.count)
    }
}
