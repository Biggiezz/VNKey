// OutputStrategy.swift
// VNKey — Vietnamese Input Method for macOS
//
// Protocol và Factory cho các chiến lược output.
// Mỗi chiến lược xử lý cách gửi text đến ứng dụng đích khác nhau:
//   - IMKClientStrategy: Dùng IMK chuẩn (native apps)
//   - CGEventStrategy: Gửi phím ảo qua CGEvent (browsers)
//   - ClipboardStrategy: Paste qua clipboard (Google Docs)

import AppKit
import InputMethodKit
import Carbon.HIToolbox

// MARK: - OutputStrategy Protocol

/// Protocol định nghĩa cách gửi text đến ứng dụng đích.
/// Mỗi implementation xử lý một loại ứng dụng khác nhau.
protocol OutputStrategy: AnyObject {

    /// Gửi marked text (text đang soạn, có gạch chân) đến ứng dụng.
    /// Client ứng dụng sẽ hiển thị text này với kiểu "đang soạn".
    ///
    /// - Parameters:
    ///   - text: Text đang soạn.
    func setMarkedText(_ text: String)

    /// Commit text (chốt text cuối cùng) vào ứng dụng.
    /// Text sẽ được chèn vĩnh viễn, không còn gạch chân.
    ///
    /// - Parameters:
    ///   - text: Text đã hoàn thành.
    func commitText(_ text: String)

    /// Xóa marked text hiện tại mà không commit gì.
    func clearMarkedText()

    /// Thực hiện cập nhật inline: xóa text cũ và chèn text mới.
    /// Dùng cho các strategy không hỗ trợ marked text.
    ///
    /// - Parameters:
    ///   - oldText: Text cũ cần xóa.
    ///   - newText: Text mới cần chèn.
    func updateInline(oldText: String, newText: String)

    /// Reset bộ nhớ tạm theo dõi văn bản hiện tại.
    func resetState()
}

// MARK: - Default Implementation

extension OutputStrategy {
    /// Mặc định: updateInline sẽ clear marked text rồi set lại.
    func updateInline(oldText: String, newText: String) {
        setMarkedText(newText)
    }

    /// Reset bộ nhớ tạm
    func resetState() {}
}

// MARK: - OutputStrategyFactory

/// Factory tạo OutputStrategy dựa trên loại ứng dụng.
enum OutputStrategyFactory {

    /// Tạo strategy phù hợp cho loại ứng dụng.
    static func make(for type: OutputStrategyType) -> OutputStrategy {
        switch type {
        case .imkClient, .cgEvent:
            return CGEventStrategy.shared
        case .clipboard:
            return ClipboardStrategy.shared
        }
    }

    /// Tạo strategy mặc định (CGEvent).
    static func makeDefault() -> OutputStrategy {
        return CGEventStrategy.shared
    }
}
