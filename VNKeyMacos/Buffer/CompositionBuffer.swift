// CompositionBuffer.swift
// VNKey — Vietnamese Input Method for macOS
//
// Quản lý trạng thái soạn thảo (composition state).
// Buffer duy trì 2 phiên bản song song:
//   - rawBuffer: ký tự gốc user gõ (vd: "vieetj")
//   - processedText: kết quả sau xử lý (vd: "việt")
//
// Mỗi khi rawBuffer thay đổi, engine tính toán lại processedText.
// Đảm bảo thread-safety bằng cách chạy trên Main Thread
// (InputMethodKit luôn gọi từ main thread).

import Foundation

// MARK: - Composition State

/// Trạng thái của buffer soạn thảo.
enum CompositionState: Sendable {
    /// Không có gì đang soạn.
    case idle
    /// Đang soạn: marked text đang hiển thị.
    case composing
}

// MARK: - CompositionBuffer

/// Quản lý trạng thái soạn thảo cho một input session.
/// Mỗi instance gắn với một IMKInputController instance.
///
/// Lifecycle:
///   idle → [user types] → composing → [user commits/space/enter] → idle
///                          ↑                        |
///                          └──── [continues typing] ─┘
final class CompositionBuffer {

    // MARK: Properties

    /// Engine xử lý tiếng Việt. Shared instance — thread-safe vì stateless.
    private let engine = VietnameseEngine()

    /// Buffer ký tự gốc (raw keystrokes).
    private(set) var rawBuffer: [Character] = []

    /// Text đã xử lý (Vietnamese output).
    private(set) var processedText: String = ""

    /// Text đã xử lý lần trước (trước khi nhận phím mới).
    /// Dùng để tính backspace count cho CGEvent strategy.
    private(set) var previousProcessedText: String = ""

    /// Trạng thái hiện tại.
    private(set) var state: CompositionState = .idle

    /// Kiểu gõ hiện tại.
    var inputMethod: InputMethod = .telex

    /// Quy tắc đặt dấu.
    var tonePlacement: TonePlacementStyle = .oldStyle

    // MARK: - Buffer Operations

    /// Thêm một ký tự vào buffer và xử lý lại.
    ///
    /// - Parameter char: Ký tự vừa gõ.
    /// - Returns: Kết quả xử lý mới.
    @discardableResult
    func append(_ char: Character) -> EngineResult {
        previousProcessedText = processedText
        rawBuffer.append(char)
        state = .composing
        return reprocess()
    }

    /// Xóa ký tự cuối trong rawBuffer (Backspace) và xử lý lại.
    ///
    /// - Returns: Kết quả xử lý mới, hoặc nil nếu buffer đã rỗng.
    @discardableResult
    func deleteBackward() -> EngineResult? {
        guard !rawBuffer.isEmpty else {
            state = .idle
            return nil
        }
        previousProcessedText = processedText
        rawBuffer.removeLast()

        if rawBuffer.isEmpty {
            processedText = ""
            state = .idle
            return EngineResult(processedText: "", hasTransformation: false)
        }

        return reprocess()
    }

    /// Lấy text hiện tại để commit và reset buffer.
    ///
    /// - Returns: Text đã xử lý sẵn sàng commit. Empty string nếu buffer rỗng.
    func commit() -> String {
        let text = processedText
        reset()
        return text
    }

    /// Reset buffer về trạng thái idle.
    func reset() {
        rawBuffer = []
        processedText = ""
        previousProcessedText = ""
        state = .idle
    }

    /// Kiểm tra buffer có đang rỗng không.
    var isEmpty: Bool {
        return rawBuffer.isEmpty
    }

    /// Kiểm tra buffer có đang composing không.
    var isComposing: Bool {
        return state == .composing
    }

    /// Số ký tự raw hiện tại.
    var rawCount: Int {
        return rawBuffer.count
    }

    // MARK: - Reprocessing

    /// Xử lý lại toàn bộ rawBuffer qua engine.
    /// Gọi mỗi khi rawBuffer thay đổi.
    @discardableResult
    private func reprocess() -> EngineResult {
        let result = engine.process(
            rawInput: rawBuffer,
            method: inputMethod,
            tonePlacement: tonePlacement
        )
        processedText = result.processedText
        return result
    }

    // MARK: - Backspace Calculation (for CGEvent/Clipboard strategies)

    /// Tính số lượng Backspace cần gửi và text cần insert
    /// khi chuyển từ previousProcessedText sang processedText.
    var backspaceInfo: (backspaceCount: Int, insertText: String) {
        return engine.calculateBackspaceAndInsert(
            oldText: previousProcessedText,
            newText: processedText
        )
    }

    // MARK: - Debug

    /// Mô tả trạng thái hiện tại (cho debugging).
    var debugDescription: String {
        return """
        CompositionBuffer:
          state: \(state)
          raw: "\(String(rawBuffer))" (\(rawBuffer.count) chars)
          processed: "\(processedText)"
          previous: "\(previousProcessedText)"
        """
    }
}
