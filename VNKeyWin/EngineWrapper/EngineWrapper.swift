// EngineWrapper.swift
// VNKey — Windows Swift Engine Wrapper
//
// File này cung cấp các C-interface (@_cdecl) để xuất (export) 
// các hàm xử lý của VietnameseEngine ra DLL nhằm sử dụng trong C++/Win32.

import Foundation

// MARK: - C API Exports

/// Xử lý chuỗi raw input và trả về kết quả tiếng Việt cùng với thông tin transformation.
/// 
/// - Parameters:
///   - rawString: Chuỗi raw input (C-string, UTF-8).
///   - methodInt: 0 = Telex, 1 = VNI, 2 = SimpleTelex.
///   - toneStyleInt: 0 = Old style, 1 = New style.
///   - outText: Con trỏ nhận chuỗi kết quả (C-string, UTF-8). Caller phải giải phóng bằng vnkey_free_string.
/// - Returns: 1 nếu có transformation, 0 nếu không.
@_cdecl("vnkey_process")
public func vnkey_process(
    rawString: UnsafePointer<CChar>?,
    methodInt: Int32,
    toneStyleInt: Int32,
    outText: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    guard let rawStr = rawString, let outPtr = outText else { return 0 }
    
    let inputStr = String(cString: rawStr)
    let method: InputMethod
    switch methodInt {
    case 1: method = .vni
    case 2: method = .simpleTelex
    default: method = .telex
    }
    
    let toneStyle: TonePlacementStyle = (toneStyleInt == 1) ? .newStyle : .oldStyle
    
    let engine = VietnameseEngine()
    let result = engine.process(rawString: inputStr, method: method, tonePlacement: toneStyle)
    
    // Tạo C-string cho output
    let cString = result.processedText.utf8CString
    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: cString.count)
    for i in 0..<cString.count {
        buffer[i] = cString[i]
    }
    
    outPtr.pointee = buffer
    return result.hasTransformation ? 1 : 0
}

/// Giải phóng vùng nhớ của C-string được phân bổ bởi Swift.
@_cdecl("vnkey_free_string")
public func vnkey_free_string(ptr: UnsafeMutablePointer<CChar>?) {
    ptr?.deallocate()
}

/// Tính số lượng backspace cần gửi và chuỗi cần chèn.
/// Trả về số lượng backspace.
@_cdecl("vnkey_calculate_backspace")
public func vnkey_calculate_backspace(
    oldText: UnsafePointer<CChar>?,
    newText: UnsafePointer<CChar>?,
    outInsertText: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    guard let oldStr = oldText, let newStr = newText, let outPtr = outInsertText else { return 0 }
    
    let old = String(cString: oldStr)
    let new = String(cString: newStr)
    
    let engine = VietnameseEngine()
    let result = engine.calculateBackspaceAndInsert(oldText: old, newText: new)
    
    let cString = result.insertText.utf8CString
    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: cString.count)
    for i in 0..<cString.count {
        buffer[i] = cString[i]
    }
    
    outPtr.pointee = buffer
    return Int32(result.backspaceCount)
}
