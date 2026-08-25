// IMKClientStrategy.swift
// Obsolete: VNKey now runs as a standalone app and does not use IMKClient.
// This empty class is kept only to maintain Xcode project structure references.

import Foundation

final class IMKClientStrategy: OutputStrategy {
    func setMarkedText(_ text: String) {}
    func commitText(_ text: String) {}
    func clearMarkedText() {}
    func updateInline(oldText: String, newText: String) {}
}
