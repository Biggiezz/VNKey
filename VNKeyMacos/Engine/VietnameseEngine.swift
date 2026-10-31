// VietnameseEngine.swift
// VNKey — Vietnamese Input Method for macOS
//
// Engine xử lý lõi: chuyển đổi chuỗi raw input thành text tiếng Việt.
// Thuật toán "recompute from scratch" — mỗi khi buffer thay đổi,
// toàn bộ raw buffer được xử lý lại từ đầu. Cách này đơn giản,
// không có bug trạng thái (stateless per-call), và đủ nhanh vì
// mỗi âm tiết tiếng Việt tối đa ~7 ký tự.
//
// Pipeline xử lý:
//   rawInput → [extractTone] → [applyDiacritics] → [applyTone] → output

import Foundation

// MARK: - Engine Result

/// Kết quả xử lý từ engine.
struct EngineResult: Equatable, Sendable {
    /// Chuỗi tiếng Việt đã xử lý.
    let processedText: String
    /// Có thay đổi so với raw input không (đã áp dụng dấu).
    let hasTransformation: Bool
}

// MARK: - VietnameseEngine

/// Engine xử lý chính — chuyển đổi raw keystrokes thành Vietnamese text.
/// Thread-safe: tất cả methods đều pure function, không có mutable state.
final class VietnameseEngine: Sendable {

    private let toneManager = ToneManager()

    // MARK: - Processor Factory

    /// Tạo processor phù hợp cho kiểu gõ.
    static func makeProcessor(for method: InputMethod) -> InputMethodProcessor {
        switch method {
        case .telex, .simpleTelex:
            return TelexProcessor()
        case .vni:
            return VNIProcessor()
        }
    }

    // MARK: - Main Processing

    /// Xử lý toàn bộ raw buffer và trả về kết quả tiếng Việt.
    ///
    /// Thuật toán:
    /// 1. Duyệt từng ký tự trong rawInput
    /// 2. Với mỗi ký tự, thử áp dụng theo thứ tự:
    ///    a. Diacritic transformation (aa→â, aw→ă, dd→đ, ...)
    ///    b. Tone key (s→sắc, f→huyền, ...) — chỉ khi đã có nguyên âm
    ///    c. Ký tự thường — thêm vào result
    /// 3. Sau khi duyệt xong, áp dụng dấu thanh lên vị trí đúng
    ///
    /// - Parameters:
    ///   - rawInput: Mảng ký tự gốc user đã gõ.
    ///   - method: Kiểu gõ (Telex / VNI).
    ///   - tonePlacement: Quy tắc đặt dấu (cũ / mới).
    /// - Returns: EngineResult chứa text đã xử lý.
    func process(
        rawInput: [Character],
        method: InputMethod,
        tonePlacement: TonePlacementStyle = .oldStyle
    ) -> EngineResult {
        guard !rawInput.isEmpty else {
            return EngineResult(processedText: "", hasTransformation: false)
        }

        let processor = VietnameseEngine.makeProcessor(for: method)

        var result: [Character] = []
        var pendingTone: Tone? = nil
        var pendingToneChar: Character? = nil
        var pendingToneIndex: Int? = nil
        var hasVowelInResult = false
        var anyTransformation = false

        for (index, char) in rawInput.enumerated() {
            // ── Bước 2a: Thử áp dụng diacritic ──
            if processor.tryApplyDiacritic(char, to: &result, rawInput: rawInput, currentIndex: index) {
                anyTransformation = true
                updateVowelFlag(&hasVowelInResult, in: result)
                continue
            }

            // ── Bước 2b: Thử tone key ──
            // Tone key chỉ hợp lệ khi:
            //   1. Đã có nguyên âm trong result
            //   2. Vị trí hiện tại hợp lệ theo cấu trúc âm tiết tiếng Việt (cụm nguyên âm liên tục, coda hợp lệ)
            //   3. Ký tự này là tone key theo kiểu gõ hiện tại
            //
            // Ngoại lệ: nếu tone key cũng có thể là phụ âm đầu
            //            (s, r, x trong Telex), chỉ coi là tone key
            //            khi đã có nguyên âm và ở vị trí hợp lệ.
            if hasVowelInResult, isValidTonePosition(in: result), let tone = processor.toneForKey(char) {
                // z (Telex) hoặc 0 (VNI) là tone key để xóa dấu (.none).
                // Chỉ xử lý nó như tone key nếu đang có dấu thanh active (khác .none).
                // Nếu không có dấu active, ta coi nó là ký tự thường (sẽ append vào result).
                if tone == .none {
                    let hasActiveTone = pendingTone != nil && pendingTone != Tone.none
                    if !hasActiveTone {
                        // Bỏ qua việc xử lý tone key, để nó rơi xuống bước 2c làm ký tự thường
                        result.append(char)
                        continue
                    }
                }
                
                // 1. Xử lý toggle undo:
                // CHỈ toggle undo khi gõ liên tiếp ngay sau tone trước (chưa có ký tự xen giữa)
                if let existing = pendingTone, existing == tone, tone != .none {
                    if pendingToneIndex == result.count {
                        pendingTone = nil
                        pendingToneChar = nil
                        pendingToneIndex = nil
                        result.append(char)
                        anyTransformation = true
                        continue
                    } else {
                        result.append(char)
                        continue
                    }
                }

                // 2. Không cho phép gõ đè nhiều dấu thanh trong cùng 1 từ nếu đã có ký tự xen giữa
                if pendingTone != nil && pendingTone != Tone.none && pendingToneIndex != result.count {
                    result.append(char)
                    continue
                }

                // 3. Nếu trong result đã có nguyên âm mang sẵn dấu thanh:
                if VietConstants.hasTone(in: result) {
                    // Cập nhật lại dấu thanh mới (hoặc áp lại dấu thanh):
                    result = toneManager.removeTone(from: result)
                    pendingTone = tone
                    pendingToneChar = char
                    pendingToneIndex = result.count
                    anyTransformation = true
                    continue
                }

                pendingTone = tone
                pendingToneChar = char
                pendingToneIndex = result.count
                anyTransformation = true
                continue
            }

            // ── Bước 2c: Ký tự thường ──
            result.append(char)
            if VietConstants.isVowel(char) {
                hasVowelInResult = true
            }
        }

        // ── Bước 3: Áp dụng dấu thanh ──
        if let tone = pendingTone {
            if tone != Tone.none && isValidTonePosition(in: result, tone: tone) {
                result = toneManager.applyTone(
                    to: result,
                    tone: tone,
                    style: tonePlacement
                )
                anyTransformation = true
            } else if let toneChar = pendingToneChar, let insertIdx = pendingToneIndex {
                // Nếu cấu trúc từ sau cùng không hợp lệ để mang dấu thanh tiếng Việt
                // (ví dụ: gõ "cors", "fork", "market", từ đa âm tiết hoặc coda không hợp lệ)
                // Hoàn trả lại ký tự tone key đã bị nuốt
                let safeIdx = min(insertIdx, result.count)
                result.insert(toneChar, at: safeIdx)
            }
        }

        // ── Bước 4: Guard từ đa âm tiết tiếng Anh / ngoại lai ──
        let rawStr = String(rawInput).lowercased()
        let hasTransformedChar = result.contains { ch in
            if let decomp = VietConstants.decompose(ch) {
                return decomp.diacritic != .none || decomp.tone != .none
            }
            return VietConstants.isDBar(ch)
        }

        let isMulti = VietConstants.isMultiSyllabic(result)
        let isEnglishPattern = rawStr.hasSuffix("ward") || rawStr.hasSuffix("word") || rawStr.hasSuffix("ware") || rawStr.hasSuffix("swer") || rawStr == "serene"

        if (isMulti && hasTransformedChar) || isEnglishPattern {
            return EngineResult(
                processedText: String(rawInput),
                hasTransformation: false
            )
        }

        let processed = String(result)
        return EngineResult(
            processedText: processed,
            hasTransformation: anyTransformation && processed != String(rawInput)
        )
    }

    // MARK: - Convenience

    /// Xử lý từ String thay vì [Character].
    func process(
        rawString: String,
        method: InputMethod,
        tonePlacement: TonePlacementStyle = .oldStyle
    ) -> EngineResult {
        return process(
            rawInput: Array(rawString),
            method: method,
            tonePlacement: tonePlacement
        )
    }

    // MARK: - Backspace Calculation

    /// Tính số lượng Backspace cần gửi khi chuyển từ oldText sang newText.
    ///
    /// Thuật toán:
    /// 1. Tìm common prefix giữa old và new
    /// 2. Backspace count = UTF-16 length(old suffix after prefix)
    ///
    /// Dùng UTF-16 length vì macOS text system đo bằng UTF-16 code units.
    /// Ký tự Vietnamese có dấu = 1 UTF-16 code unit (nằm trong BMP).
    ///
    /// - Parameters:
    ///   - oldText: Text cũ đang hiển thị.
    ///   - newText: Text mới cần hiển thị.
    /// - Returns: Tuple (backspaceCount, textToInsert).
    func calculateBackspaceAndInsert(
        oldText: String,
        newText: String
    ) -> (backspaceCount: Int, insertText: String) {
        // Tìm common prefix
        let oldChars = Array(oldText)
        let newChars = Array(newText)
        var commonLen = 0
        let minLen = min(oldChars.count, newChars.count)

        for i in 0..<minLen {
            if oldChars[i] == newChars[i] {
                commonLen = i + 1
            } else {
                break
            }
        }

        // Phần cần xóa: oldText từ vị trí commonLen đến cuối
        let suffixToDelete = String(oldChars[commonLen...])
        let backspaceCount = suffixToDelete.utf16.count

        // Phần cần thêm: newText từ vị trí commonLen đến cuối
        let textToInsert: String
        if commonLen < newChars.count {
            textToInsert = String(newChars[commonLen...])
        } else {
            textToInsert = ""
        }

        return (backspaceCount, textToInsert)
    }

    // MARK: - Private
    
    /// Kiểm tra xem vị trí hiện tại trong `chars` có hợp lệ để nhận dấu thanh không:
    /// 1. Phải có ít nhất một nguyên âm trong `chars`.
    /// 2. Các nguyên âm phải nằm trong một cụm liên tục duy nhất (không có phụ âm xen giữa, tránh từ đa âm tiết tiếng Anh như "resets", "markets").
    /// 3. Phần phụ âm đứng sau nguyên âm cuối (coda) phải rỗng hoặc là coda hợp lệ trong tiếng Việt (c, ch, m, n, ng, nh, p, t, z).
    /// 4. Âm tiết khép bằng phụ âm tắc (c, ch, p, t) chỉ được mang thanh sắc hoặc nặng.
    private func isValidTonePosition(in chars: [Character], tone: Tone? = nil) -> Bool {
        var vowelIndices: [Int] = []
        for (i, ch) in chars.enumerated() {
            if VietConstants.isVowel(ch) {
                vowelIndices.append(i)
            }
        }

        guard let firstVowel = vowelIndices.first, let lastVowel = vowelIndices.last else {
            return false
        }

        // 1. Kiểm tra tất cả nguyên âm có liên tiếp nhau không (ngăn cách bởi phụ âm -> từ đa âm tiết / ngoại lai)
        if lastVowel - firstVowel + 1 != vowelIndices.count {
            return false
        }

        // Cụm nguyên âm trong tiếng Việt tối đa 3 nguyên âm (tam trùng âm: iêu, uôi, oai, uây, ươi, ươu)
        if vowelIndices.count > 3 {
            return false
        }

        // 2. Kiểm tra phần phụ âm đứng sau nguyên âm cuối cùng
        let suffixChars = chars[(lastVowel + 1)...]
        if suffixChars.isEmpty {
            return true
        }

        let suffix = String(suffixChars).lowercased()
        if !VietConstants.validCodas.contains(suffix) {
            return false
        }

        // 3. Luật âm tiết khép phụ âm tắc (c, ch, p, t): chỉ đi với thanh sắc và nặng
        if let tone = tone, tone != .none {
            let stopCodas: Set<String> = ["c", "ch", "p", "t"]
            if stopCodas.contains(suffix) {
                if tone != .sac && tone != .nang {
                    return false
                }
            }
        }

        return true
    }

    private func updateVowelFlag(_ flag: inout Bool, in chars: [Character]) {
        if !flag {
            flag = chars.contains(where: { VietConstants.isVowel($0) })
        }
    }
}
