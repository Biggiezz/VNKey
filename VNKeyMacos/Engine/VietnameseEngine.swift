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
            //   2. Ký tự này là tone key theo kiểu gõ hiện tại
            //
            // Ngoại lệ: nếu tone key cũng có thể là phụ âm đầu
            //            (s, r, x trong Telex), chỉ coi là tone key
            //            khi đã có nguyên âm.
            if hasVowelInResult, let tone = processor.toneForKey(char) {
                // z (Telex) hoặc 0 (VNI) là tone key để xóa dấu (.none).
                // Chỉ xử lý nó như tone key nếu đang có dấu thanh active (khác .none).
                // Nếu không có dấu active, ta coi nó là ký tự thường (sẽ append vào result).
                if tone == .none {
                    let hasActiveTone = pendingTone != nil && pendingTone != .none
                    if !hasActiveTone {
                        // Bỏ qua việc xử lý tone key, để nó rơi xuống bước 2c làm ký tự thường
                        result.append(char)
                        continue
                    }
                }
                
                // Xử lý toggle: nếu gõ cùng tone 2 lần → undo
                if let existing = pendingTone, existing == tone, tone != .none {
                    // Undo: xóa dấu, thêm ký tự literal
                    pendingTone = nil
                    result.append(char)
                } else {
                    pendingTone = tone
                    anyTransformation = true
                }
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
            result = toneManager.applyTone(
                to: result,
                tone: tone,
                style: tonePlacement
            )
            anyTransformation = true
        }

        let processed = String(result)
        return EngineResult(
            processedText: processed,
            hasTransformation: anyTransformation
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

    private func updateVowelFlag(_ flag: inout Bool, in chars: [Character]) {
        if !flag {
            flag = chars.contains(where: { VietConstants.isVowel($0) })
        }
    }
}
