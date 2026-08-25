// ToneManager.swift
// VNKey — Vietnamese Input Method for macOS
//
// Quản lý logic đặt dấu thanh điệu lên nguyên âm tiếng Việt.
// Hỗ trợ 2 quy tắc: dấu cũ (phổ biến) và dấu mới (ngôn ngữ học).
//
// Quy tắc đặt dấu cũ (Old Style / Traditional):
//   - Nếu có nguyên âm mang dấu phụ (â, ă, ê, ô, ơ, ư) → đặt dấu lên nó
//   - 1 nguyên âm → đặt dấu lên nó
//   - 2 nguyên âm + phụ âm cuối → đặt dấu lên nguyên âm thứ 2
//   - 2 nguyên âm, không phụ âm cuối → đặt dấu lên nguyên âm thứ 1
//   - 3 nguyên âm → đặt dấu lên nguyên âm thứ 2

import Foundation

// MARK: - ToneManager

final class ToneManager: Sendable {

    // MARK: - Public API

    /// Áp dụng dấu thanh lên vị trí đúng trong mảng ký tự.
    ///
    /// - Parameters:
    ///   - chars: Mảng ký tự đã được xử lý dấu phụ (diacritics), có thể có dấu thanh cũ.
    ///   - tone: Dấu thanh cần áp dụng.
    ///   - style: Quy tắc đặt dấu (cũ/mới). Mặc định: cũ.
    /// - Returns: Mảng ký tự mới với dấu thanh đã được đặt đúng vị trí.
    func applyTone(
        to chars: [Character],
        tone: Tone,
        style: TonePlacementStyle = .oldStyle
    ) -> [Character] {
        guard tone != .none else {
            // Xóa tất cả dấu thanh, giữ nguyên dấu phụ
            return removeTone(from: chars)
        }

        // Bước 1: Xóa dấu thanh cũ (nếu có) khỏi tất cả ký tự
        var cleaned = removeTone(from: chars)

        // Bước 2: Tìm vị trí nguyên âm cần đặt dấu
        guard let targetIndex = findToneTarget(in: cleaned, style: style) else {
            return chars // Không tìm thấy nguyên âm → giữ nguyên
        }

        // Bước 3: Đặt dấu lên nguyên âm đích
        let targetChar = cleaned[targetIndex]
        if let toned = applyToneToChar(targetChar, tone: tone) {
            cleaned[targetIndex] = toned
        }

        return cleaned
    }

    /// Xóa dấu thanh khỏi tất cả ký tự, giữ nguyên dấu phụ.
    ///
    /// Ví dụ: "việt" → "viêt" (xóa nặng nhưng giữ ê)
    func removeTone(from chars: [Character]) -> [Character] {
        return chars.map { char in
            guard let decomp = VietConstants.decompose(char) else { return char }
            if decomp.tone == .none { return char }
            // Tổng hợp lại không có dấu thanh
            return VietConstants.compose(
                base: decomp.base,
                diacritic: decomp.diacritic,
                tone: .none,
                uppercase: decomp.isUppercase
            ) ?? char
        }
    }

    /// Áp dụng dấu thanh lên một ký tự đơn lẻ.
    func applyToneToChar(_ char: Character, tone: Tone) -> Character? {
        guard let decomp = VietConstants.decompose(char) else {
            // Thử xem nó có phải nguyên âm gốc ASCII không
            let lower = Character(char.lowercased())
            guard VietConstants.baseVowels.contains(lower) else { return nil }
            return VietConstants.compose(
                base: lower,
                diacritic: .none,
                tone: tone,
                uppercase: char.isUppercase
            )
        }
        return VietConstants.compose(
            base: decomp.base,
            diacritic: decomp.diacritic,
            tone: tone,
            uppercase: decomp.isUppercase
        )
    }

    /// Lấy dấu thanh hiện tại của ký tự (nếu có).
    func currentTone(of char: Character) -> Tone {
        return VietConstants.decompose(char)?.tone ?? .none
    }

    // MARK: - Tone Target Finding

    /// Tìm index của nguyên âm cần đặt dấu thanh.
    ///
    /// Thuật toán:
    /// 1. Tìm tất cả vị trí nguyên âm trong mảng ký tự
    /// 2. Áp dụng quy tắc đặt dấu theo style
    private func findToneTarget(
        in chars: [Character],
        style: TonePlacementStyle
    ) -> Int? {
        // Thu thập vị trí và thông tin tất cả nguyên âm
        var vowelPositions: [(index: Int, decomp: VowelDecomposition?)] = []

        for (i, char) in chars.enumerated() {
            if VietConstants.isVowel(char) {
                vowelPositions.append((i, VietConstants.decompose(char)))
            }
        }

        guard !vowelPositions.isEmpty else { return nil }

        // Nếu chỉ có 1 nguyên âm → đặt dấu lên nó
        if vowelPositions.count == 1 {
            return vowelPositions[0].index
        }

        // Special case for "ươ" (ư + ơ): the tone mark always goes to the second vowel "ơ"
        for i in 0..<(vowelPositions.count - 1) {
            if let firstDecomp = vowelPositions[i].decomp,
               let secondDecomp = vowelPositions[i+1].decomp,
               firstDecomp.base == "u" && firstDecomp.diacritic == .horn,
               secondDecomp.base == "o" && secondDecomp.diacritic == .horn {
                return vowelPositions[i+1].index
            }
        }

        // Quy tắc 1: Nếu có nguyên âm mang dấu phụ → ưu tiên nó
        // (Áp dụng cho cả old và new style)
        for vp in vowelPositions {
            if let decomp = vp.decomp, decomp.diacritic != .none {
                return vp.index
            }
        }

        // Kiểm tra có phụ âm cuối sau nhóm nguyên âm không
        let lastVowelIdx = vowelPositions.last!.index
        let hasCoda = lastVowelIdx < chars.count - 1

        switch style {
        case .oldStyle:
            return findToneTargetOldStyle(
                vowelPositions: vowelPositions,
                hasCoda: hasCoda
            )
        case .newStyle:
            return findToneTargetNewStyle(
                vowelPositions: vowelPositions,
                hasCoda: hasCoda
            )
        }
    }

    /// Quy tắc đặt dấu cũ (Traditional):
    /// - 2 nguyên âm + coda → nguyên âm thứ 2
    /// - 2 nguyên âm, không coda → nguyên âm thứ 1
    /// - 3+ nguyên âm → nguyên âm thứ 2
    private func findToneTargetOldStyle(
        vowelPositions: [(index: Int, decomp: VowelDecomposition?)],
        hasCoda: Bool
    ) -> Int {
        let count = vowelPositions.count

        if count >= 3 {
            // 3+ nguyên âm: đặt dấu lên nguyên âm thứ 2
            return vowelPositions[1].index
        }

        if count == 2 {
            if hasCoda {
                // 2 nguyên âm + phụ âm cuối: đặt dấu lên nguyên âm thứ 2
                return vowelPositions[1].index
            } else {
                // 2 nguyên âm, không phụ âm cuối: đặt dấu lên nguyên âm thứ 1
                return vowelPositions[0].index
            }
        }

        // Fallback: nguyên âm đầu tiên
        return vowelPositions[0].index
    }

    /// Quy tắc đặt dấu mới (Linguistic):
    /// Luôn đặt dấu trên nguyên âm chính (nucleus) của vần.
    /// Thực tế: thường là nguyên âm cuối cùng (hoặc thứ 2 nếu có 3).
    private func findToneTargetNewStyle(
        vowelPositions: [(index: Int, decomp: VowelDecomposition?)],
        hasCoda: Bool
    ) -> Int {
        let count = vowelPositions.count

        if count >= 3 {
            return vowelPositions[1].index
        }

        // Dấu mới: luôn đặt trên nguyên âm cuối
        if count == 2 {
            return vowelPositions[1].index
        }

        return vowelPositions[0].index
    }
}
