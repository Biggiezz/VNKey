// VNIProcessor.swift
// VNKey — Vietnamese Input Method for macOS
//
// Xử lý kiểu gõ VNI.
// Quy tắc VNI:
//   Tones:      1=sắc, 2=huyền, 3=hỏi, 4=ngã, 5=nặng, 0=xóa dấu
//   Diacritics: 6=mũ(â,ê,ô), 7=móc(ơ,ư), 8=trăng(ă), 9=đ

import Foundation

// MARK: - VNIProcessor

final class VNIProcessor: InputMethodProcessor {

    // MARK: Tone Key

    func isToneKey(_ char: Character) -> Bool {
        return VietConstants.vniToneKeys[char] != nil
    }

    func toneForKey(_ char: Character) -> Tone? {
        return VietConstants.vniToneKeys[char]
    }

    // MARK: D-Bar (9 → đ)

    func isDBarTrigger(_ char: Character, previous: Character?) -> Bool {
        guard char == "9" else { return false }
        guard let prev = previous else { return false }
        let lower = Character(prev.lowercased())
        return lower == "d" || VietConstants.isDBar(prev)
    }

    // MARK: Diacritic Application

    func tryApplyDiacritic(_ char: Character, to result: inout [Character], rawInput: [Character], currentIndex: Int) -> Bool {
        guard !result.isEmpty else { return false }

        // ── Case 1: Key '9' → d/D → đ/Đ ──
        if char == "9" {
            if let lastIdx = findLastD(in: result) {
                let target = result[lastIdx]
                if VietConstants.isDBar(target) {
                    // Undo: đ + 9 → d9
                    let isUpper = target == "\u{0110}"
                    result[lastIdx] = isUpper ? "D" : "d"
                    result.append(char)
                    return true
                } else {
                    // Apply: d + 9 → đ
                    if let dbar = VietConstants.toDBar(target) {
                        result[lastIdx] = dbar
                        return true
                    }
                }
            }
            return false
        }

        // ── Case 2: Key '6' → circumflex (a→â, e→ê, o→ô) ──
        if char == "6" {
            return tryApplyVNIDiacritic(
                .circumflex,
                targets: ["a", "e", "o"],
                to: &result,
                triggerChar: char
            )
        }

        // ── Case 3: Key '7' → horn (o→ơ, u→ư) ──
        if char == "7" {
            return tryApplyVNIDiacritic(
                .horn,
                targets: ["o", "u"],
                to: &result,
                triggerChar: char
            )
        }

        // ── Case 4: Key '8' → breve (a→ă) ──
        if char == "8" {
            return tryApplyVNIDiacritic(
                .breve,
                targets: ["a"],
                to: &result,
                triggerChar: char
            )
        }

        return false
    }

    // MARK: - Private Helpers

    /// Áp dụng một loại diacritic VNI lên nguyên âm đích gần nhất.
    private func tryApplyVNIDiacritic(
        _ diacritic: Diacritic,
        targets: Set<Character>,
        to result: inout [Character],
        triggerChar: Character
    ) -> Bool {
        // Tìm nguyên âm đích gần nhất (từ cuối mảng)
        guard let targetIdx = findLastVowelMatching(targets, in: result) else {
            return false
        }

        let target = result[targetIdx]
        let decomp = VietConstants.decompose(target)
        let targetBase = decomp?.base ?? Character(target.lowercased())
        let targetIsUpper = decomp?.isUppercase ?? target.isUppercase
        let currentDiacritic = decomp?.diacritic ?? .none
        let currentTone = decomp?.tone ?? .none

        guard targets.contains(targetBase) else { return false }

        if currentDiacritic == diacritic {
            // Undo: â + 6 → a6
            let plain = VietConstants.compose(
                base: targetBase, diacritic: .none,
                tone: currentTone, uppercase: targetIsUpper
            ) ?? target
            result[targetIdx] = plain
            result.append(triggerChar)
            return true
        } else {
            // Apply: a + 6 → â
            if let composed = VietConstants.compose(
                base: targetBase, diacritic: diacritic,
                tone: currentTone, uppercase: targetIsUpper
            ) {
                result[targetIdx] = composed
                
                // ── Luật dấu móc kép (Double horn rule) cho VNI: uo + 7 → ươ ──
                if diacritic == .horn && targetBase == "o" && targetIdx > 0 {
                    let prevChar = result[targetIdx - 1]
                    let decompPrev = VietConstants.decompose(prevChar)
                    let prevBase = decompPrev?.base ?? Character(prevChar.lowercased())
                    if prevBase == "u" {
                        let prevTone = decompPrev?.tone ?? .none
                        let prevIsUpper = decompPrev?.isUppercase ?? prevChar.isUppercase
                        if let prevComposed = VietConstants.compose(
                            base: "u", diacritic: .horn,
                            tone: prevTone, uppercase: prevIsUpper
                        ) {
                            result[targetIdx - 1] = prevComposed
                        }
                    }
                }
                
                return true
            }
        }

        return false
    }

    /// Tìm nguyên âm cuối cùng có base trong tập targets.
    private func findLastVowelMatching(
        _ targets: Set<Character>,
        in chars: [Character]
    ) -> Int? {
        for i in stride(from: chars.count - 1, through: 0, by: -1) {
            let ch = chars[i]
            if let decomp = VietConstants.decompose(ch), targets.contains(decomp.base) {
                return i
            }
            let lower = Character(ch.lowercased())
            if targets.contains(lower) {
                return i
            }
        }
        return nil
    }

    /// Tìm chữ 'd' hoặc 'đ' cuối cùng trong mảng.
    private func findLastD(in chars: [Character]) -> Int? {
        for i in stride(from: chars.count - 1, through: 0, by: -1) {
            let ch = chars[i]
            let lower = Character(ch.lowercased())
            if lower == "d" || VietConstants.isDBar(ch) {
                return i
            }
        }
        return nil
    }
}
