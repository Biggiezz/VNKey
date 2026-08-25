// AppDetector.swift
// VNKey — Vietnamese Input Method for macOS
//
// Phát hiện ứng dụng đang active để chọn OutputStrategy phù hợp.
// Sử dụng NSWorkspace và bundle identifier để phân loại ứng dụng.
//
// Phân loại:
//   Native apps (TextEdit, Xcode, ...) → IMKClientStrategy
//   Browsers (Chrome, Safari, ...) → CGEventStrategy
//   Google Docs (detected via URL/title) → ClipboardStrategy
//   Electron apps (VSCode, Slack, ...) → CGEventStrategy

import AppKit

// MARK: - App Category

/// Phân loại ứng dụng theo cách xử lý input.
enum AppCategory: Sendable {
    /// Native macOS app — hỗ trợ IMK đầy đủ.
    case native
    /// Web browser — hỗ trợ IMK hạn chế, cần CGEvent.
    case browser
    /// Google Docs hoặc web app tương tự — cần Clipboard paste.
    case webAppStubborn
    /// Electron-based app — cần CGEvent.
    case electron
}

// MARK: - AppDetector

/// Phát hiện loại ứng dụng đang active và đề xuất OutputStrategy.
final class AppDetector {

    // MARK: Known Bundle Identifiers

    /// Browsers: dùng CGEvent strategy.
    private static let browserBundleIds: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Beta",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser",  // Arc
        "org.chromium.Chromium",
    ]

    /// Electron apps: dùng CGEvent strategy.
    private static let electronBundleIds: Set<String> = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "com.spotify.client",
        "com.figma.Desktop",
        "com.notion.id",
        "md.obsidian",
        "com.logseq.logseq",
        "com.linear",
        "com.vng.zalodesktop",
        "com.vng.zalo",
        "ru.keepcoder.Telegram",
        "com.telegram.desktop",
        "com.skype.skype",
        "com.viber.osx",
        "com.facebook.messenger"
    ]

    /// Apps cần Clipboard strategy (luôn luôn, không cần detect URL).
    private static let clipboardBundleIds: Set<String> = [
        // Thêm vào đây nếu phát hiện app nào cần clipboard
    ]

    /// Google Docs URL patterns.
    private static let googleDocsPatterns: [String] = [
        "docs.google.com/document",
        "docs.google.com/spreadsheets",
        "docs.google.com/presentation",
        "docs.google.com"
    ]

    // MARK: - Detection

    /// Phát hiện loại ứng dụng đang active.
    ///
    /// - Returns: Tuple (category, strategyType).
    static func detectCurrentApp() -> (category: AppCategory, strategy: OutputStrategyType) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return (.native, .imkClient)
        }

        return detect(bundleIdentifier: bundleId)
    }

    /// Phát hiện loại ứng dụng từ bundle identifier.
    static func detect(bundleIdentifier: String) -> (category: AppCategory, strategy: OutputStrategyType) {
        // 1. Check preferences override
        if let overrideType = PreferencesManager.shared.strategyType(
            forBundleIdentifier: bundleIdentifier
        ) {
            let category: AppCategory
            switch overrideType {
            case .imkClient:  category = .native
            case .cgEvent:    category = .browser
            case .clipboard:  category = .webAppStubborn
            }
            return (category, overrideType)
        }

        // 2. Check clipboard-required apps
        if clipboardBundleIds.contains(bundleIdentifier) {
            return (.webAppStubborn, .clipboard)
        }

        // 3. Check Electron apps
        if electronBundleIds.contains(bundleIdentifier) {
            return (.electron, .cgEvent)
        }

        // 4. Check browsers
        if browserBundleIds.contains(bundleIdentifier) {
            return (.browser, .cgEvent)
        }

        // 5. Default: native IMK
        return (.native, .imkClient)
    }

    /// Kiểm tra xem browser hiện tại có đang mở Google Docs không.
    ///
    /// Sử dụng Accessibility API để đọc URL/title của window.
    /// Fallback: nếu không đọc được, trả về false (dùng CGEvent thay vì clipboard).
    ///
    /// - Parameter bundleIdentifier: Bundle ID của browser.
    /// - Returns: true nếu đang mở Google Docs.
    static func isGoogleDocs(bundleIdentifier: String) -> Bool {
        // Chỉ kiểm tra cho browsers
        guard browserBundleIds.contains(bundleIdentifier) else { return false }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var windowValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        )

        guard result == .success else { return false }
        let windowElement = windowValue as! AXUIElement

        // 1. Thử lấy URL từ thuộc tính AXDocument hoặc AXURL của Window (hoạt động trên cả Safari & Chrome)
        var docValue: AnyObject?
        if AXUIElementCopyAttributeValue(windowElement, kAXDocumentAttribute as CFString, &docValue) == .success,
           let url = docValue as? String {
            let lowerUrl = url.lowercased()
            for pattern in googleDocsPatterns {
                if lowerUrl.contains(pattern) {
                    return true
                }
            }
        }

        var urlValue: AnyObject?
        if AXUIElementCopyAttributeValue(windowElement, "AXURL" as CFString, &urlValue) == .success,
           let url = urlValue as? String {
            let lowerUrl = url.lowercased()
            for pattern in googleDocsPatterns {
                if lowerUrl.contains(pattern) {
                    return true
                }
            }
        }

        // 2. Thử lấy title của window để match từ khóa tiếng Việt / tiếng Anh
        var titleValue: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(
            windowElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        if titleResult == .success, let title = titleValue as? String {
            let lowerTitle = title.lowercased()
            if lowerTitle.contains("google docs") || lowerTitle.contains("google sheets") ||
               lowerTitle.contains("google slides") || lowerTitle.contains("google tài liệu") ||
               lowerTitle.contains("google trang tính") || lowerTitle.contains("google trình bày") ||
               lowerTitle.contains("docs.google.com") || lowerTitle.contains("sheets.google.com") ||
               lowerTitle.contains("slides.google.com") {
                return true
            }

            for pattern in googleDocsPatterns {
                if lowerTitle.contains(pattern) {
                    return true
                }
            }
        }

        // 3. Thử lấy URL từ address bar (Chrome-specific fallback)
        if bundleIdentifier.contains("Chrome") || bundleIdentifier.contains("chromium") {
            if let url = getChromeURL(appElement: appElement) {
                let lowerUrl = url.lowercased()
                for pattern in googleDocsPatterns {
                    if lowerUrl.contains(pattern) {
                        return true
                    }
                }
            }
        }

        return false
    }

    /// Lấy URL từ Chrome address bar qua Accessibility API.
    private static func getChromeURL(appElement: AXUIElement) -> String? {
        // Chrome exposes URL through AXDocument attribute on the window
        var windowValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        )

        guard result == .success else { return nil }

        var docValue: AnyObject?
        let docResult = AXUIElementCopyAttributeValue(
            windowValue as! AXUIElement,
            kAXDocumentAttribute as CFString,
            &docValue
        )

        if docResult == .success, let url = docValue as? String {
            return url
        }

        return nil
    }

    // MARK: - Strategy Selection

    /// Lấy OutputStrategy phù hợp cho bundle identifier hiện tại.
    /// Bao gồm kiểm tra Google Docs cho browsers.
    static func strategyType(
        forBundleIdentifier bundleId: String
    ) -> OutputStrategyType {
        let (category, defaultStrategy) = detect(bundleIdentifier: bundleId)

        // Nếu là browser, kiểm tra thêm Google Docs
        if category == .browser {
            if isGoogleDocs(bundleIdentifier: bundleId) {
                return .cgEvent
            }
        }

        return defaultStrategy
    }
}
