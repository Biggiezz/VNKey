// ClipboardStrategy.swift
// VNKey — Vietnamese Input Method for macOS
//
// Chiến lược output "cuối cùng" dùng Clipboard + Cmd+V paste.
// Dành cho các ứng dụng "bướng bỉnh" nhất: Google Docs, một số
// Electron apps chặn cả CGEvent thông thường.
//
// Cách hoạt động:
//   1. Lưu nội dung clipboard hiện tại (để restore sau)
//   2. Gửi Backspace ảo để xóa text cũ
//   3. Copy text mới vào clipboard
//   4. Gửi Cmd+V ảo để paste
//   5. Restore clipboard gốc (sau 200ms delay)
//
// ⚠️ Trade-off: Phương pháp này can thiệp vào clipboard của user.
// Cần restore nhanh và chính xác để user không nhận ra.
// ⚠️ YÊU CẦU: Accessibility permission.

import AppKit
import InputMethodKit
import Carbon.HIToolbox

// MARK: - ClipboardStrategy

final class ClipboardStrategy: OutputStrategy {

    static let shared = ClipboardStrategy()

    private init() {
        // Khởi tạo event source với trạng thái riêng (private).
        privateEventSource = CGEventSource(stateID: .privateState)
    }

    // MARK: Constants

    private static let backspaceKeyCode: CGKeyCode = 0x33
    private static let vKeyCode: CGKeyCode = 0x09  // 'V' key
    private static let interEventDelayUs: UInt32 = 1_500
    private static let postBackspaceDelayUs: UInt32 = 5_000  // 5ms
    private static let clipboardRestoreDelayMs: Int = 250  // 250ms

    // MARK: State

    /// Event source riêng (private) — cô lập khỏi HID system state.
    private let privateEventSource: CGEventSource?

    /// Serial queue to handle clipboard restore operations.
    private let outputQueue = DispatchQueue(label: "com.vnkey.clipboard.output", qos: .userInteractive)

    /// Text hiện đang được hiển thị qua strategy này.
    private var currentCommittedText: String = ""

    /// Danh sách items clipboard gốc lưu trước khi gõ từ mới
    private var savedItems: [NSPasteboardItem]? = nil

    /// Pasteboard chính.
    private let pasteboard = NSPasteboard.general

    // MARK: OutputStrategy Implementation

    func setMarkedText(_ text: String) {
        // ClipboardStrategy không dùng marked text.
        // Commit ngay mỗi lần update.
        updateInline(oldText: "", newText: text)
    }

    func commitText(_ text: String) {
        // Text đã đúng — reset state.
        outputQueue.async { [weak self] in
            guard let self = self else { return }
            self.currentCommittedText = ""
            self.performRestore()
        }
    }

    func clearMarkedText() {
        outputQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.currentCommittedText.isEmpty {
                let count = self.currentCommittedText.utf16.count
                self.sendBackspaces(count: count)
                self.currentCommittedText = ""
                self.performRestore()
            }
        }
    }

    func updateInline(oldText: String, newText: String) {
        outputQueue.async { [weak self] in
            guard let self = self else { return }

            let effectiveOld = self.currentCommittedText.isEmpty ? oldText : self.currentCommittedText

            // Nếu text không đổi → skip
            guard effectiveOld != newText else { return }

            // Tính delta
            let (backspaceCount, _) = self.calculateDelta(
                oldText: effectiveOld,
                newText: newText
            )

            // Bước 1: Xóa text cũ hoàn toàn bằng backspace
            let fullBackspaceCount = effectiveOld.utf16.count
            if fullBackspaceCount > 0 {
                self.sendBackspaces(count: fullBackspaceCount)
                usleep(Self.postBackspaceDelayUs)
            }

            // Bước 2: Paste text mới qua clipboard
            if !newText.isEmpty {
                self.pasteText(newText)
            }

            // Update state
            self.currentCommittedText = newText
        }
    }

    // MARK: - Clipboard Paste

    /// Copy text vào clipboard, gửi Cmd+V.
    private func pasteText(_ text: String) {
        // ── Bước 1: Lưu clipboard hiện tại (chỉ lưu 1 lần duy nhất ở đầu từ) ──
        if savedItems == nil {
            savedItems = saveClipboard()
        }

        // ── Bước 2: Set text mới vào clipboard ──
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Delay nhỏ để clipboard update
        usleep(2_000)

        // ── Bước 3: Gửi Cmd+V (paste) ──
        sendPasteCommand()
    }

    /// Khôi phục lại clipboard sau khi kết thúc việc soạn thảo từ
    private func performRestore() {
        guard savedItems != nil else { return }
        
        // Delay nhỏ để đảm bảo lệnh paste cuối cùng đã được ứng dụng nhận diện
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + .milliseconds(120)) { [weak self] in
            guard let self = self else { return }
            self.outputQueue.async {
                // Chỉ restore nếu từ đang soạn đã kết thúc (currentCommittedText rỗng)
                if self.currentCommittedText.isEmpty, let items = self.savedItems {
                    self.restoreClipboard(items)
                    self.savedItems = nil
                }
            }
        }
    }

    /// Gửi Cmd+V qua CGEvent.
    private func sendPasteCommand() {
        // Cmd+V Key Down
        if let keyDown = CGEvent(
            keyboardEventSource: privateEventSource,
            virtualKey: Self.vKeyCode,
            keyDown: true
        ) {
            keyDown.flags = .maskCommand
            keyDown.setIntegerValueField(.eventSourceUserData, value: 99999)
            keyDown.post(tap: .cghidEventTap)
        }

        usleep(Self.interEventDelayUs)

        // Cmd+V Key Up
        if let keyUp = CGEvent(
            keyboardEventSource: privateEventSource,
            virtualKey: Self.vKeyCode,
            keyDown: false
        ) {
            keyUp.flags = .maskCommand
            keyUp.setIntegerValueField(.eventSourceUserData, value: 99999)
            keyUp.post(tap: .cghidEventTap)
        }

        usleep(Self.interEventDelayUs)
    }

    // MARK: - Clipboard Save / Restore

    /// Lưu nội dung clipboard hiện tại.
    private func saveClipboard() -> [NSPasteboardItem] {
        // Tạo copies của pasteboard items hiện tại
        var savedItems: [NSPasteboardItem] = []

        if let items = pasteboard.pasteboardItems {
            for item in items {
                let copy = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        copy.setData(data, forType: type)
                    }
                }
                savedItems.append(copy)
            }
        }

        return savedItems
    }

    /// Restore nội dung clipboard đã lưu.
    private func restoreClipboard(_ items: [NSPasteboardItem]) {
        guard !items.isEmpty else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    // MARK: - Backspace Sending

    private func sendBackspaces(count: Int) {
        guard count > 0 else { return }

        for _ in 0..<count {
            if let keyDown = CGEvent(
                keyboardEventSource: privateEventSource,
                virtualKey: Self.backspaceKeyCode,
                keyDown: true
            ) {
                keyDown.flags = []
                keyDown.setIntegerValueField(.eventSourceUserData, value: 99999)
                keyDown.post(tap: .cghidEventTap)
            }
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

    // MARK: - Delta Calculation

    private func calculateDelta(
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

        let suffixToDelete = commonLen < oldChars.count
            ? String(oldChars[commonLen...]) : ""
        let insertText = commonLen < newChars.count
            ? String(newChars[commonLen...]) : ""

        return (suffixToDelete.utf16.count, insertText)
    }

    // MARK: - Utility

    func resetState() {
        outputQueue.async { [weak self] in
            self?.currentCommittedText = ""
        }
    }
}
