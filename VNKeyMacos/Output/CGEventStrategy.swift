// CGEventStrategy.swift
// VNKey — Vietnamese Input Method for macOS
//
// Chiến lược output dùng CGEvent (virtual key events).
// Dùng cho browsers (Chrome, Safari, Edge) và một số Electron apps
// khi IMK marked text không hoạt động tốt.
//
// Cách hoạt động:
//   1. Tính số Backspace cần gửi để xóa text cũ
//   2. Gửi Backspace ảo qua CGEvent
//   3. Gửi text mới qua CGEvent (từng ký tự Unicode)
//
// ⚠️ YÊU CẦU: Accessibility permission phải được cấp.
// System Settings → Privacy & Security → Accessibility → VNKey ✓
//
// ⚠️ QUAN TRỌNG: Sử dụng CGEventSource với trạng thái .privateState
//   để cô lập hoàn toàn sự kiện tổng hợp khỏi trạng thái bàn phím thật.
//   Điều này ngăn chặn event tap chặn lại chính event do VNKey tạo ra
//   và tránh race condition giữa phím thật và phím ảo.

import AppKit
import InputMethodKit
import Carbon.HIToolbox

// MARK: - CGEventStrategy

final class CGEventStrategy: OutputStrategy {

    static let shared = CGEventStrategy()

    private init() {
        // Khởi tạo event source với trạng thái riêng (private).
        // Điều này đảm bảo các sự kiện tổng hợp hoàn toàn cô lập
        // khỏi trạng thái bàn phím vật lý (HID system state).
        privateEventSource = CGEventSource(stateID: .privateState)
    }

    // MARK: Constants

    /// Keycode của phím Backspace (Delete) trên macOS.
    private static let backspaceKeyCode: CGKeyCode = 0x33  // 51

    /// Keycode của phím Left Arrow trên macOS.
    private static let leftArrowKeyCode: CGKeyCode = 0x7B  // 123

    /// Delay giữa các sự kiện CGEvent (microseconds).
    /// 1000μs = 1ms. Cần đủ chậm để app đích xử lý kịp.
    /// Safari/WebKit cần >= 2ms giữa các event để DOM cập nhật kịp.
    private static let interEventDelayUs: UInt32 = 3_000  // 3ms

    /// Delay sau khi gửi xong tất cả backspaces, trước khi gửi text mới.
    /// Cho browsers thời gian xử lý DOM updates.
    /// Safari cần >= 6ms để render xong backspace trước khi nhận ký tự mới.
    private static let postBackspaceDelayUs: UInt32 = 8_000  // 8ms

    // MARK: Private state

    /// Event source riêng (private) — cô lập khỏi HID system state.
    /// Tạo 1 lần, tái sử dụng cho mọi sự kiện tổng hợp.
    private let privateEventSource: CGEventSource?

    /// Text đang được hiển thị (committed) bởi strategy này.
    /// Dùng để tính backspace khi cần update.
    private var currentCommittedText: String = ""

    // MARK: OutputStrategy Implementation

    func setMarkedText(_ text: String) {
        // CGEventStrategy KHÔNG dùng marked text.
        // Thay vào đó, mỗi keystroke được commit ngay (inline editing).
        // Hàm này được gọi bởi controller khi cần update display.
        updateInline(oldText: currentCommittedText, newText: text)
    }

    func commitText(_ text: String) {
        // Khi commit, text hiện tại đã đúng (đã được updateInline trước đó).
        // Chỉ cần reset tracking state.
        currentCommittedText = ""
    }

    func clearMarkedText() {
        // Xóa text đã committed bằng backspace
        if !currentCommittedText.isEmpty {
            sendBackspaces(count: currentCommittedText.utf16.count)
            currentCommittedText = ""
        }
    }

    func updateInline(oldText: String, newText: String) {
        // ── Thực thi đồng bộ (synchronous) trên main thread ──
        // Event tap callback chạy trên main thread, CGEvent.post() là thread-safe.
        // Thực thi đồng bộ đảm bảo KHÔNG có khoảng trống thời gian giữa
        // việc nuốt phím gốc và gửi phím thay thế, loại bỏ race condition.

        let effectiveOld = currentCommittedText.isEmpty ? oldText : currentCommittedText

        // Tính toán delta
        var (backspaceCount, insertText) = calculateDelta(
            oldText: effectiveOld,
            newText: newText
        )

        // Phát hiện ứng dụng phía trước và loại ứng dụng
        let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let appCategory = AppDetector.detect(bundleIdentifier: bundleId).category
        let isChromiumLike = PreferencesManager.shared.fixChromium && (appCategory == .browser || appCategory == .electron)
        let isSafariOrFirefox = (appCategory == .browser) && (bundleId.lowercased().contains("safari") || bundleId.lowercased().contains("firefox") || bundleId.lowercased().contains("mozilla"))
        let isChromium = isChromiumLike && !isSafariOrFirefox

        var shouldUseSelectionReplacement = false
        if isChromium && backspaceCount > 0 && !insertText.isEmpty {
            shouldUseSelectionReplacement = true
        }

        if isSafariOrFirefox && backspaceCount > 0 && !insertText.isEmpty {
            // Workaround cho Safari/Firefox: gửi ký tự rỗng ZWNJ để làm đứt kết nối autocomplete
            sendUnicodeString("\u{200C}")
            backspaceCount += 1
        }

        // Bước 1: Xóa phần cũ (bằng Backspaces hoặc Shift + Left Arrow)
        if shouldUseSelectionReplacement {
            sendShiftAndLeftArrow(count: backspaceCount)
            backspaceCount = 0
            usleep(Self.postBackspaceDelayUs)
        } else if backspaceCount > 0 {
            sendBackspaces(count: backspaceCount)
            usleep(Self.postBackspaceDelayUs)
        }

        // Bước 2: Gửi text mới
        if !insertText.isEmpty {
            sendUnicodeString(insertText)
        }

        // Update tracking state
        currentCommittedText = newText
    }

    // MARK: - CGEvent Sending

    /// Gửi N phím Shift + Left Arrow ảo để bôi đen/chọn text cần thay thế.
    private func sendShiftAndLeftArrow(count: Int) {
        guard count > 0 else { return }

        for _ in 0..<count {
            // Key Down
            if let keyDown = CGEvent(
                keyboardEventSource: privateEventSource,
                virtualKey: Self.leftArrowKeyCode,
                keyDown: true
            ) {
                keyDown.flags = .maskShift
                keyDown.setIntegerValueField(.eventSourceUserData, value: 99999)
                keyDown.post(tap: .cghidEventTap)
            }

            // Key Up
            if let keyUp = CGEvent(
                keyboardEventSource: privateEventSource,
                virtualKey: Self.leftArrowKeyCode,
                keyDown: false
            ) {
                keyUp.flags = .maskShift
                keyUp.setIntegerValueField(.eventSourceUserData, value: 99999)
                keyUp.post(tap: .cghidEventTap)
            }

            usleep(Self.interEventDelayUs)
        }
    }

    /// Gửi N phím Backspace ảo.
    ///
    /// Mỗi Backspace = 1 pair (keyDown + keyUp).
    /// Delay nhỏ giữa mỗi pair để app đích xử lý kịp.
    private func sendBackspaces(count: Int) {
        guard count > 0 else { return }

        for _ in 0..<count {
            // Key Down
            if let keyDown = CGEvent(
                keyboardEventSource: privateEventSource,
                virtualKey: Self.backspaceKeyCode,
                keyDown: true
            ) {
                keyDown.flags = []  // Không kèm modifier nào
                keyDown.setIntegerValueField(.eventSourceUserData, value: 99999)
                keyDown.post(tap: .cghidEventTap)
            }

            // Key Up
            if let keyUp = CGEvent(
                keyboardEventSource: privateEventSource,
                virtualKey: Self.backspaceKeyCode,
                keyDown: false
            ) {
                keyUp.flags = []
                keyUp.setIntegerValueField(.eventSourceUserData, value: 99999)
                keyUp.post(tap: .cghidEventTap)
            }

            usleep(Self.interEventDelayUs)
        }
    }

    /// Gửi một chuỗi Unicode qua CGEvent.
    ///
    /// Sử dụng `CGEvent.keyboardSetUnicodeString()` để gửi từng ký tự.
    /// Mỗi ký tự = 1 pair (keyDown chứa Unicode + keyUp).
    private func sendUnicodeString(_ string: String) {
        for char in string {
            let utf16 = Array(String(char).utf16)

            // Key Down với Unicode string
            if let keyDown = CGEvent(
                keyboardEventSource: privateEventSource,
                virtualKey: 0,  // Virtual key 0 — actual char comes from Unicode
                keyDown: true
            ) {
                keyDown.keyboardSetUnicodeString(
                    stringLength: utf16.count,
                    unicodeString: utf16
                )
                keyDown.setIntegerValueField(.eventSourceUserData, value: 99999)
                keyDown.post(tap: .cghidEventTap)
            }

            // Key Up
            if let keyUp = CGEvent(
                keyboardEventSource: privateEventSource,
                virtualKey: 0,
                keyDown: false
            ) {
                keyUp.setIntegerValueField(.eventSourceUserData, value: 99999)
                keyUp.post(tap: .cghidEventTap)
            }

            usleep(Self.interEventDelayUs)
        }
    }

    // MARK: - Delta Calculation

    /// Tính toán delta giữa old text và new text.
    /// Tìm common prefix để minimize số backspaces cần gửi.
    ///
    /// Ví dụ:
    ///   old = "vie"  →  new = "viê"
    ///   common prefix = "vi" (2 chars)
    ///   backspace = UTF16Len("e") = 1
    ///   insert = "ê"
    func calculateDelta(
        oldText: String,
        newText: String
    ) -> (backspaceCount: Int, insertText: String) {
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

        // Phần cần xóa
        let suffixToDelete: String
        if commonLen < oldChars.count {
            suffixToDelete = String(oldChars[commonLen...])
        } else {
            suffixToDelete = ""
        }
        let backspaceCount = suffixToDelete.utf16.count

        // Phần cần thêm
        let insertText: String
        if commonLen < newChars.count {
            insertText = String(newChars[commonLen...])
        } else {
            insertText = ""
        }

        return (backspaceCount, insertText)
    }

    // MARK: - Utility

    /// Reset trạng thái tracking.
    /// Gọi khi commit, thay đổi focus, hoặc cần đồng bộ lại state.
    func resetState() {
        currentCommittedText = ""
    }
}
