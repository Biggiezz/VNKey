// PreferencesManager.swift
// VNKey — Vietnamese Input Method for macOS
//
// Quản lý cài đặt người dùng qua UserDefaults.
// Lưu trữ: kiểu gõ (Telex/VNI), quy tắc đặt dấu, danh sách ứng dụng
// sử dụng chiến lược output đặc biệt.

import Foundation

// MARK: - Tone Placement Style

/// Quy tắc đặt dấu thanh.
enum TonePlacementStyle: String, Sendable {
    /// Dấu cũ: đặt gần giữa từ (hóa, thúy). Phổ biến hơn.
    case oldStyle = "old"
    /// Dấu mới: đặt trên nguyên âm chính (hoá, thuý). Theo chuẩn ngôn ngữ học.
    case newStyle = "new"
}

// MARK: - Output Strategy Type

/// Loại chiến lược output cho từng ứng dụng.
enum OutputStrategyType: String, Sendable {
    case imkClient  = "imk"        // Dùng IMK chuẩn (setMarkedText / insertText)
    case cgEvent    = "cgevent"    // Gửi phím ảo qua CGEvent
    case clipboard  = "clipboard"  // Paste qua clipboard
}

// MARK: - PreferencesManager

/// Singleton quản lý tất cả cài đặt người dùng.
/// Thread-safe: tất cả truy cập qua UserDefaults (đã thread-safe sẵn).
final class PreferencesManager: @unchecked Sendable {

    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    // MARK: Keys

    private enum Keys {
        static let inputMethod      = "VNKey_InputMethod"
        static let tonePlacement    = "VNKey_TonePlacement"
        static let isEnabled        = "VNKey_IsEnabled"
        static let appStrategyMap   = "VNKey_AppStrategyMap"
        static let showMarkedText   = "VNKey_ShowMarkedText"
        static let autoCommitDelay  = "VNKey_AutoCommitDelayMs"

        // New properties
        static let codeTable        = "VNKey_CodeTable"
        static let switchKeyControl = "VNKey_SwitchKeyControl"
        static let switchKeyOption  = "VNKey_SwitchKeyOption"
        static let switchKeyCommand = "VNKey_SwitchKeyCommand"
        static let switchKeyShift   = "VNKey_SwitchKeyShift"
        static let switchKeyBeep    = "VNKey_SwitchKeyBeep"
        static let switchKeyText    = "VNKey_SwitchKeyText"

        static let checkSpelling    = "VNKey_CheckSpelling"
        static let restoreIfInvalid = "VNKey_RestoreIfInvalid"
        static let allowFZWJ        = "VNKey_AllowFZWJ"
        static let tempOffSpelling  = "VNKey_TempOffSpelling"
        static let quickTelex       = "VNKey_QuickTelex"

        static let useMacro         = "VNKey_UseMacro"
        static let macroStartCons   = "VNKey_MacroStartCons"
        static let macroEndCons     = "VNKey_MacroEndCons"
        static let autoCapsMacro    = "VNKey_AutoCapsMacro"

        static let showIconOnDock   = "VNKey_ShowIconOnDock"
        static let showUIOnStartup  = "VNKey_ShowUIOnStartup"
        static let grayIcon         = "VNKey_GrayIcon"
        static let runOnStartup     = "VNKey_RunOnStartup"
        static let fixChromium      = "VNKey_FixChromium"
        static let fixUnderline     = "VNKey_FixUnderline"
        static let sendKeyStep      = "VNKey_SendKeyStep"
        static let checkUpdate      = "VNKey_CheckUpdate"
        static let smartSwitch      = "VNKey_SmartSwitch"
    }

    // MARK: - Initialization

    private init() {
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.inputMethod:       InputMethod.telex.rawValue,
            Keys.tonePlacement:     TonePlacementStyle.oldStyle.rawValue,
            Keys.isEnabled:         true,
            Keys.showMarkedText:    true,
            Keys.autoCommitDelay:   0,
            Keys.appStrategyMap:    defaultAppStrategyMap,
            
            // New options defaults
            Keys.codeTable:         0, // 0 = Unicode
            Keys.switchKeyControl:  true,
            Keys.switchKeyOption:   false,
            Keys.switchKeyCommand:  false,
            Keys.switchKeyShift:    false,
            Keys.switchKeyBeep:     true,
            Keys.switchKeyText:     "Space",
            
            Keys.checkSpelling:     true,
            Keys.restoreIfInvalid:  true,
            Keys.allowFZWJ:         false,
            Keys.tempOffSpelling:   false,
            Keys.quickTelex:        true,
            
            Keys.useMacro:          true,
            Keys.macroStartCons:    false,
            Keys.macroEndCons:      false,
            Keys.autoCapsMacro:     true,
            
            Keys.showIconOnDock:    true,
            Keys.showUIOnStartup:   false,
            Keys.grayIcon:          true,
            Keys.runOnStartup:      true,
            Keys.fixChromium:       true,
            Keys.fixUnderline:      true,
            Keys.sendKeyStep:       false,
            Keys.checkUpdate:       true,
            Keys.smartSwitch:       true
        ])
    }

    /// Mapping mặc định: bundleIdentifier → output strategy.
    private let defaultAppStrategyMap: [String: String] = [
        "com.google.Chrome":               OutputStrategyType.cgEvent.rawValue,
        "com.google.Chrome.canary":        OutputStrategyType.cgEvent.rawValue,
        "com.apple.Safari":                OutputStrategyType.cgEvent.rawValue,
        "com.microsoft.edgemac":           OutputStrategyType.cgEvent.rawValue,
        "org.mozilla.firefox":             OutputStrategyType.cgEvent.rawValue,
        "com.brave.Browser":               OutputStrategyType.cgEvent.rawValue,
        "com.operasoftware.Opera":         OutputStrategyType.cgEvent.rawValue,
        "com.microsoft.VSCode":            OutputStrategyType.cgEvent.rawValue,
        "com.tinyspeck.slackmacgap":       OutputStrategyType.cgEvent.rawValue,
        "com.hnc.Discord":                 OutputStrategyType.cgEvent.rawValue,
    ]

    // MARK: - Properties

    /// Kiểu gõ hiện tại (Telex / VNI / Simple Telex).
    var inputMethod: InputMethod {
        get {
            let raw = defaults.string(forKey: Keys.inputMethod) ?? InputMethod.telex.rawValue
            return InputMethod(rawValue: raw) ?? .telex
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.inputMethod) }
    }

    /// Quy tắc đặt dấu thanh (cũ / mới).
    var tonePlacement: TonePlacementStyle {
        get {
            let raw = defaults.string(forKey: Keys.tonePlacement) ?? TonePlacementStyle.oldStyle.rawValue
            return TonePlacementStyle(rawValue: raw) ?? .oldStyle
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.tonePlacement) }
    }

    /// Bộ gõ có đang bật không.
    var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.isEnabled) }
        set { defaults.set(newValue, forKey: Keys.isEnabled) }
    }

    /// Có hiển thị marked text (gạch chân) không.
    var showMarkedText: Bool {
        get { defaults.bool(forKey: Keys.showMarkedText) }
        set { defaults.set(newValue, forKey: Keys.showMarkedText) }
    }

    // New Properties bindings
    var codeTable: Int {
        get { defaults.integer(forKey: Keys.codeTable) }
        set { defaults.set(newValue, forKey: Keys.codeTable) }
    }
    var switchKeyControl: Bool {
        get { defaults.bool(forKey: Keys.switchKeyControl) }
        set { defaults.set(newValue, forKey: Keys.switchKeyControl) }
    }
    var switchKeyOption: Bool {
        get { defaults.bool(forKey: Keys.switchKeyOption) }
        set { defaults.set(newValue, forKey: Keys.switchKeyOption) }
    }
    var switchKeyCommand: Bool {
        get { defaults.bool(forKey: Keys.switchKeyCommand) }
        set { defaults.set(newValue, forKey: Keys.switchKeyCommand) }
    }
    var switchKeyShift: Bool {
        get { defaults.bool(forKey: Keys.switchKeyShift) }
        set { defaults.set(newValue, forKey: Keys.switchKeyShift) }
    }
    var switchKeyBeep: Bool {
        get { defaults.bool(forKey: Keys.switchKeyBeep) }
        set { defaults.set(newValue, forKey: Keys.switchKeyBeep) }
    }
    var switchKeyText: String {
        get { defaults.string(forKey: Keys.switchKeyText) ?? "Space" }
        set { defaults.set(newValue, forKey: Keys.switchKeyText) }
    }

    var checkSpelling: Bool {
        get { defaults.bool(forKey: Keys.checkSpelling) }
        set { defaults.set(newValue, forKey: Keys.checkSpelling) }
    }
    var restoreIfInvalid: Bool {
        get { defaults.bool(forKey: Keys.restoreIfInvalid) }
        set { defaults.set(newValue, forKey: Keys.restoreIfInvalid) }
    }
    var allowFZWJ: Bool {
        get { defaults.bool(forKey: Keys.allowFZWJ) }
        set { defaults.set(newValue, forKey: Keys.allowFZWJ) }
    }
    var tempOffSpelling: Bool {
        get { defaults.bool(forKey: Keys.tempOffSpelling) }
        set { defaults.set(newValue, forKey: Keys.tempOffSpelling) }
    }
    var quickTelex: Bool {
        get { defaults.bool(forKey: Keys.quickTelex) }
        set { defaults.set(newValue, forKey: Keys.quickTelex) }
    }

    var useMacro: Bool {
        get { defaults.bool(forKey: Keys.useMacro) }
        set { defaults.set(newValue, forKey: Keys.useMacro) }
    }
    var macroStartCons: Bool {
        get { defaults.bool(forKey: Keys.macroStartCons) }
        set { defaults.set(newValue, forKey: Keys.macroStartCons) }
    }
    var macroEndCons: Bool {
        get { defaults.bool(forKey: Keys.macroEndCons) }
        set { defaults.set(newValue, forKey: Keys.macroEndCons) }
    }
    var autoCapsMacro: Bool {
        get { defaults.bool(forKey: Keys.autoCapsMacro) }
        set { defaults.set(newValue, forKey: Keys.autoCapsMacro) }
    }

    var showIconOnDock: Bool {
        get { defaults.bool(forKey: Keys.showIconOnDock) }
        set { defaults.set(newValue, forKey: Keys.showIconOnDock) }
    }
    var showUIOnStartup: Bool {
        get { defaults.bool(forKey: Keys.showUIOnStartup) }
        set { defaults.set(newValue, forKey: Keys.showUIOnStartup) }
    }
    var grayIcon: Bool {
        get { defaults.bool(forKey: Keys.grayIcon) }
        set { defaults.set(newValue, forKey: Keys.grayIcon) }
    }
    var runOnStartup: Bool {
        get { defaults.bool(forKey: Keys.runOnStartup) }
        set { defaults.set(newValue, forKey: Keys.runOnStartup) }
    }
    var fixChromium: Bool {
        get { defaults.bool(forKey: Keys.fixChromium) }
        set { defaults.set(newValue, forKey: Keys.fixChromium) }
    }
    var fixUnderline: Bool {
        get { defaults.bool(forKey: Keys.fixUnderline) }
        set { defaults.set(newValue, forKey: Keys.fixUnderline) }
    }
    var sendKeyStep: Bool {
        get { defaults.bool(forKey: Keys.sendKeyStep) }
        set { defaults.set(newValue, forKey: Keys.sendKeyStep) }
    }
    var checkUpdate: Bool {
        get { defaults.bool(forKey: Keys.checkUpdate) }
        set { defaults.set(newValue, forKey: Keys.checkUpdate) }
    }
    var smartSwitch: Bool {
        get { defaults.bool(forKey: Keys.smartSwitch) }
        set { defaults.set(newValue, forKey: Keys.smartSwitch) }
    }

    // MARK: - App Strategy Mapping

    func strategyType(forBundleIdentifier bundleId: String) -> OutputStrategyType? {
        guard let map = defaults.dictionary(forKey: Keys.appStrategyMap) as? [String: String],
              let rawValue = map[bundleId] else {
            return nil
        }
        return OutputStrategyType(rawValue: rawValue)
    }

    func setStrategyType(_ type: OutputStrategyType, forBundleIdentifier bundleId: String) {
        var map = (defaults.dictionary(forKey: Keys.appStrategyMap) as? [String: String]) ?? [:]
        map[bundleId] = type.rawValue
        defaults.set(map, forKey: Keys.appStrategyMap)
    }

    func removeStrategyOverride(forBundleIdentifier bundleId: String) {
        var map = (defaults.dictionary(forKey: Keys.appStrategyMap) as? [String: String]) ?? [:]
        map.removeValue(forKey: bundleId)
        defaults.set(map, forKey: Keys.appStrategyMap)
    }
}
