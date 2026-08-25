// AppDelegate.swift
// VNKey — Standalone Vietnamese Input Method for macOS
//
// NSApplication delegate quản lý UI Menu Bar và quyền Accessibility.

import AppKit
import Carbon.HIToolbox
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: - Properties

    /// Status Bar Item trên macOS Menu Bar.
    private var statusItem: NSStatusItem!

    /// Timer kiểm tra quyền Accessibility định kỳ sau khi mở Cài đặt.
    private var permissionTimer: Timer?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("VNKey: Application launched")

        // 1. Tạo Menu Bar Status Item
        setupStatusItem()

        // 2. Kiểm tra và yêu cầu Accessibility permission
        checkAccessibilityPermission()

        NSLog("VNKey: Initialization completed ✓")
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("VNKey: Application terminating")
        GlobalEventTapManager.shared.stop()
        permissionTimer?.invalidate()
    }

    // MARK: - Menu Bar UI Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        updateStatusButton()

        // Tạo dropdown menu
        let menu = NSMenu()
        menu.delegate = self

        // Bật/Tắt Tiếng Việt
        let toggleItem = NSMenuItem(title: "Bật Tiếng Việt", action: #selector(toggleVietnamese), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        // Submenu: Kiểu gõ
        let inputMethodMenu = NSMenu()
        let telexItem = NSMenuItem(title: "Telex", action: #selector(setInputMethodTelex), keyEquivalent: "")
        telexItem.target = self
        let vniItem = NSMenuItem(title: "VNI", action: #selector(setInputMethodVNI), keyEquivalent: "")
        vniItem.target = self
        inputMethodMenu.addItem(telexItem)
        inputMethodMenu.addItem(vniItem)

        let inputMethodParent = NSMenuItem(title: "Kiểu gõ", action: nil, keyEquivalent: "")
        inputMethodParent.submenu = inputMethodMenu
        menu.addItem(inputMethodParent)

        menu.addItem(NSMenuItem.separator())

        // Bảng điều khiển
        let controlPanelItem = NSMenuItem(title: "Bảng điều khiển...", action: #selector(showControlPanel), keyEquivalent: "")
        controlPanelItem.target = self
        menu.addItem(controlPanelItem)

        menu.addItem(NSMenuItem.separator())

        // Thoát
        let quitItem = NSMenuItem(title: "Thoát", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func updateStatusButton() {
        if let button = statusItem.button {
            button.title = PreferencesManager.shared.isEnabled ? "V" : "E"
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuState()
    }

    private func updateMenuState() {
        let prefs = PreferencesManager.shared

        // Cập nhật text của mục Bật/Tắt
        if let toggleItem = statusItem.menu?.items[0] {
            toggleItem.title = prefs.isEnabled ? "Tắt Tiếng Việt" : "Bật Tiếng Việt"
        }

        // Cập nhật checkmark cho Kiểu gõ
        if let inputMethodParent = statusItem.menu?.items[1], let submenu = inputMethodParent.submenu {
            let currentMethod = prefs.inputMethod
            submenu.items[0].state = (currentMethod == .telex) ? .on : .off
            submenu.items[1].state = (currentMethod == .vni) ? .on : .off
        }
    }

    // MARK: - Menu Actions

    @objc private func toggleVietnamese() {
        PreferencesManager.shared.isEnabled.toggle()
        updateStatusButton()
        GlobalEventTapManager.shared.syncPreferences()
        NSLog("VNKey: Toggled Vietnamese to \(PreferencesManager.shared.isEnabled)")
    }

    @objc private func setInputMethodTelex() {
        PreferencesManager.shared.inputMethod = .telex
        GlobalEventTapManager.shared.syncPreferences()
        NSLog("VNKey: Set input method to Telex")
    }

    @objc private func setInputMethodVNI() {
        PreferencesManager.shared.inputMethod = .vni
        GlobalEventTapManager.shared.syncPreferences()
        NSLog("VNKey: Set input method to VNI")
    }

    @objc private func showControlPanel() {
        ControlPanelWindowController.shared.showPanel()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Accessibility Permissions

    private func checkAccessibilityPermission() {
        if AXIsProcessTrusted() {
            NSLog("VNKey: Accessibility permission granted ✓")
            GlobalEventTapManager.shared.start()
        } else {
            NSLog("VNKey: Accessibility permission not granted. Requesting user action...")
            showAccessibilityDialog()
        }
    }

    private func showAccessibilityDialog() {
        // Trigger system prompt once so the app appears in settings list
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)

        let alert = NSAlert()
        alert.messageText = "Cần cấp quyền Trợ năng (Accessibility)"
        alert.informativeText = "VNKey cần quyền Trợ năng để có thể tự động bỏ dấu tiếng Việt khi bạn gõ chữ toàn hệ thống.\n\nVui lòng mở Cài đặt hệ thống, chọn Quyền riêng tư & Bảo mật -> Trợ năng và gạt bật VNKey."
        alert.addButton(withTitle: "Mở Cài đặt hệ thống")
        alert.addButton(withTitle: "Thoát")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            schedulePermissionCheck()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }

    private func schedulePermissionCheck() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.permissionTimer = nil
                NSLog("VNKey: Accessibility permission granted in background ✓")
                GlobalEventTapManager.shared.start()
            }
        }
    }
}

// MARK: - GlobalEventTapManager

final class GlobalEventTapManager {
    static let shared = GlobalEventTapManager()

    private init() {}

    private let buffer = CompositionBuffer()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Trạng thái theo dõi phím chuyển đổi chế độ gõ bằng modifier keys.
    private var lastModifierKeyCode: CGKeyCode? = nil
    private var lastModifierDownTime: TimeInterval = 0
    private var hasOtherKeyPressedDuringModifier: Bool = false

    /// Đồng bộ preferences vào buffer.
    func syncPreferences() {
        let prefs = PreferencesManager.shared
        buffer.inputMethod = prefs.inputMethod
        buffer.tonePlacement = prefs.tonePlacement
        
        // Cập nhật trạng thái enabled/disabled
        if !prefs.isEnabled {
            buffer.reset()
        }
    }

    /// Khởi động lắng nghe sự kiện bàn phím toàn cục.
    func start() {
        guard eventTap == nil else { return }

        // Lắng nghe sự kiện: keyDown, mouse clicks (cho focus change detection),
        // và flagsChanged (cho modifier keys)
        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return GlobalEventTapManager.shared.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            NSLog("VNKey: Failed to create event tap")
            return
        }

        self.eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("VNKey: Global event tap started successfully ✓")
    }

    /// Ngừng lắng nghe.
    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        buffer.reset()
        NSLog("VNKey: Global event tap stopped.")
    }

    // MARK: - Event Interception Handler

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // ── Xử lý sự kiện event tap bị disable bởi hệ thống ──
        // macOS có thể tự disable event tap nếu callback mất quá lâu.
        // Khi đó, type sẽ là .tapDisabledByTimeout hoặc .tapDisabledByUserInput.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Bỏ qua các sự kiện ảo do chính VNKey sinh ra để tránh lặp vô hạn (infinite loop)
        let userData = event.getIntegerValueField(.eventSourceUserData)
        if userData == 99999 {
            return Unmanaged.passUnretained(event)
        }

        // Theo dõi phím khác có được bấm cùng lúc với Modifier hay không
        if type == .keyDown || type == .leftMouseDown || type == .rightMouseDown {
            hasOtherKeyPressedDuringModifier = true
        }

        // ── Xử lý Mouse Click — reset state khi user thay đổi focus ──
        if type == .leftMouseDown || type == .rightMouseDown {
            if buffer.isComposing {
                buffer.commit()
            }
            CGEventStrategy.shared.resetState()
            ClipboardStrategy.shared.resetState()
            return Unmanaged.passUnretained(event)
        }

        // ── Xử lý flagsChanged — Chuyển chế độ gõ bằng modifier hotkeys ──
        if type == .flagsChanged {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            
            // Check các phím chuyển đổi chế độ gõ được cấu hình trong cài đặt
            var isTargetModifier = false
            var isDown = false
            
            let isControl = (keyCode == 59 || keyCode == 62)
            let isOption = (keyCode == 58 || keyCode == 61)
            let isCommand = (keyCode == 55 || keyCode == 54)
            let isShift = (keyCode == 56 || keyCode == 60)
            
            if isControl && PreferencesManager.shared.switchKeyControl {
                isTargetModifier = true
                isDown = flags.contains(.maskControl)
            } else if isOption && PreferencesManager.shared.switchKeyOption {
                isTargetModifier = true
                isDown = flags.contains(.maskAlternate)
            } else if isCommand && PreferencesManager.shared.switchKeyCommand {
                isTargetModifier = true
                isDown = flags.contains(.maskCommand)
            } else if isShift && PreferencesManager.shared.switchKeyShift {
                isTargetModifier = true
                isDown = flags.contains(.maskShift)
            }
            
            if isTargetModifier {
                if isDown {
                    lastModifierKeyCode = keyCode
                    lastModifierDownTime = NSDate.timeIntervalSinceReferenceDate
                    hasOtherKeyPressedDuringModifier = false
                } else if lastModifierKeyCode == keyCode {
                    let now = NSDate.timeIntervalSinceReferenceDate
                    let duration = now - lastModifierDownTime
                    if duration < 0.4 && !hasOtherKeyPressedDuringModifier {
                        toggleLanguageMode()
                    }
                    lastModifierKeyCode = nil
                }
            }

            if buffer.isComposing {
                buffer.commit()
            }
            CGEventStrategy.shared.resetState()
            ClipboardStrategy.shared.resetState()
            return Unmanaged.passUnretained(event)
        }

        // Chỉ xử lý khi bộ gõ được kích hoạt
        guard PreferencesManager.shared.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        // Lấy keycode và flags
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Bỏ qua nếu có các phím modifier (Cmd, Ctrl, Option)
        let ignoredFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
        if !flags.intersection(ignoredFlags).isEmpty {
            if buffer.isComposing {
                buffer.commit()
            }
            CGEventStrategy.shared.resetState()
            ClipboardStrategy.shared.resetState()
            return Unmanaged.passUnretained(event)
        }

        // Chuyển CGEvent sang NSEvent để lấy ký tự nhập vào
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }
        let characters = nsEvent.characters ?? ""

        // ── Xử lý phím đặc biệt ──

        // Backspace
        if keyCode == kVK_Delete {
            if handleBackspace() {
                return nil // nuốt phím Backspace
            }
            return Unmanaged.passUnretained(event)
        }

        // Forward Delete (Fn + Backspace hoặc phím Delete rời)
        if keyCode == 0x75 { // kVK_ForwardDelete = 117 (0x75)
            if buffer.isComposing {
                buffer.commit()
            }
            CGEventStrategy.shared.resetState()
            ClipboardStrategy.shared.resetState()
            return Unmanaged.passUnretained(event)
        }

        // Enter / Return
        if keyCode == kVK_Return || keyCode == kVK_ANSI_KeypadEnter {
            handleCommitKey()
            return Unmanaged.passUnretained(event)
        }

        // Tab
        if keyCode == kVK_Tab {
            handleCommitKey()
            return Unmanaged.passUnretained(event)
        }

        // Escape
        if keyCode == kVK_Escape {
            if handleEscape() {
                return nil // nuốt phím Escape
            }
            return Unmanaged.passUnretained(event)
        }

        // Các phím điều hướng (Arrow keys, Home, End, PageUp, PageDown)
        if isNavigationKey(keyCode) {
            if buffer.isComposing {
                buffer.commit()
            }
            CGEventStrategy.shared.resetState()
            ClipboardStrategy.shared.resetState()
            return Unmanaged.passUnretained(event)
        }

        // ── Xử lý ký tự thường ──
        guard let char = characters.first, char.isASCII else {
            if buffer.isComposing {
                buffer.commit()
            }
            CGEventStrategy.shared.resetState()
            ClipboardStrategy.shared.resetState()
            return Unmanaged.passUnretained(event)
        }

        // Phím Space
        if char == " " {
            if handleSpace() {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        // Dấu câu hoặc ký tự đặc biệt
        if isPunctuation(char) {
            handleCommitKey()
            return Unmanaged.passUnretained(event)
        }

        // Ký tự chữ cái hoặc số (trong VNI mode)
        if char.isLetter || (buffer.inputMethod == .vni && char.isNumber) {
            if handleCharacterInput(char) {
                return nil // nuốt phím gốc
            }
            return Unmanaged.passUnretained(event)
        }

        // Số trong Telex mode
        if char.isNumber {
            if buffer.isComposing {
                buffer.commit()
            }
            CGEventStrategy.shared.resetState()
            ClipboardStrategy.shared.resetState()
            return Unmanaged.passUnretained(event)
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Key Actions

    private func handleCharacterInput(_ char: Character) -> Bool {
        syncPreferences()

        let oldText = buffer.processedText

        // Thêm vào buffer
        buffer.append(char)
        let newText = buffer.processedText

        // Luôn gạt bỏ phím gốc và giả lập qua hàng đợi CGEvent để tránh tranh chấp (race condition)
        updateStrategy(newText: newText, oldText: oldText)
        return true
    }

    private func handleBackspace() -> Bool {
        guard buffer.isComposing else {
            return false
        }

        let oldText = buffer.processedText
        buffer.deleteBackward()
        let newText = buffer.processedText

        updateStrategy(newText: newText, oldText: oldText)
        return true
    }

    private func handleSpace() -> Bool {
        if buffer.isComposing {
            let oldText = buffer.processedText
            buffer.commit()
            // Type the space via strategy queue and reset tracking
            updateStrategy(newText: oldText + " ", oldText: oldText)
            CGEventStrategy.shared.resetState()
            ClipboardStrategy.shared.resetState()
            return true // swallow space
        }
        return false // let Space pass through natively
    }

    private func handleEscape() -> Bool {
        guard buffer.isComposing else {
            return false
        }

        let oldText = buffer.processedText
        let rawText = String(buffer.rawBuffer)
        buffer.reset()

        updateStrategy(newText: rawText, oldText: oldText)
        CGEventStrategy.shared.resetState()
        ClipboardStrategy.shared.resetState()
        return true
    }

    private func handleCommitKey() {
        if buffer.isComposing {
            buffer.commit()
            CGEventStrategy.shared.resetState()
            ClipboardStrategy.shared.resetState()
        }
    }

    // MARK: - Screen Update Strategy Dispatcher

    private func updateStrategy(newText: String, oldText: String) {
        let strategyType: OutputStrategyType
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontApp.bundleIdentifier {
            let appStrategy = AppDetector.strategyType(forBundleIdentifier: bundleId)
            // Vì IMKClientStrategy không dùng trong chế độ standalone, ta map nó về cgEvent
            strategyType = (appStrategy == .imkClient) ? .cgEvent : appStrategy
        } else {
            strategyType = .cgEvent
        }

        let strategy = OutputStrategyFactory.make(for: strategyType)
        strategy.updateInline(oldText: oldText, newText: newText)
    }

    // MARK: - Helper Checkers

    private func isNavigationKey(_ keyCode: UInt16) -> Bool {
        let navKeys: Set<UInt16> = [
            UInt16(kVK_UpArrow),
            UInt16(kVK_DownArrow),
            UInt16(kVK_LeftArrow),
            UInt16(kVK_RightArrow),
            UInt16(kVK_PageUp),
            UInt16(kVK_PageDown),
            UInt16(kVK_Home),
            UInt16(kVK_End),
        ]
        return navKeys.contains(keyCode)
    }

    private func isPunctuation(_ char: Character) -> Bool {
        return char.isPunctuation || char.isSymbol ||
               char == "." || char == "," || char == ";" ||
               char == ":" || char == "!" || char == "?" ||
               char == "(" || char == ")" || char == "[" ||
               char == "]" || char == "{" || char == "}" ||
               char == "/" || char == "\\" || char == "|" ||
               char == "'" || char == "\"" || char == "`" ||
               char == "@" || char == "#" || char == "$" ||
               char == "%" || char == "^" || char == "&" ||
               char == "*" || char == "-" || char == "_" ||
               char == "+" || char == "=" || char == "~"
    }

    private func toggleLanguageMode() {
        let prefs = PreferencesManager.shared
        prefs.isEnabled = !prefs.isEnabled
        GlobalEventTapManager.shared.syncPreferences()
        
        // Cập nhật trạng thái hiển thị trên Menu Bar
        DispatchQueue.main.async {
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.updateStatusButton()
            }
        }
        
        if prefs.switchKeyBeep {
            NSSound.beep()
        }
        
        NSLog("VNKey: Switch shortcut triggered. Enabled: \(prefs.isEnabled)")
    }
}
