// main.swift
// VNKey — Vietnamese Input Method for macOS
//
// Entry point cho ứng dụng Input Method.
//
// Luồng khởi tạo:
//   1. Tạo IMKServer với connection name từ Info.plist
//   2. IMKServer lắng nghe kết nối từ hệ thống
//   3. Khi user chọn VNKey làm input method, macOS gửi events
//      đến IMKServer, server tạo VNKeyInputController instances
//   4. NSApplication.run() giữ process sống
//
// ⚠️ QUAN TRỌNG:
//   - File này KHÔNG dùng @main hoặc AppDelegate entry point
//     vì Input Method cần khởi tạo IMKServer TRƯỚC NSApplication
//   - IMKServer phải tồn tại suốt lifecycle của ứng dụng

import AppKit
import InputMethodKit

// MARK: - Main

autoreleasepool {
    // Khởi tạo và chạy NSApplication
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate

    NSLog("VNKey: Starting NSApplication run loop...")
    app.run()
}
