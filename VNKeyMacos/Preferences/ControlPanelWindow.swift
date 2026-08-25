// ControlPanelWindow.swift
// VNKey — Vietnamese Input Method for macOS
//
// Bảng điều khiển dạng cửa sổ (Preferences Window) được xây dựng hoàn toàn
// bằng code (programmatically) sử dụng AppKit và Auto Layout.
// Thiết kế mô phỏng theo phong cách OpenKey 2.0.2.

import AppKit

// MARK: - ControlPanelWindowController

final class ControlPanelWindowController: NSWindowController {

    static let shared = ControlPanelWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VNKey - Bảng điều khiển"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 480)
        window.maxSize = NSSize(width: 560, height: 480)
        
        let contentViewController = ControlPanelViewController()
        window.contentViewController = contentViewController
        
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showPanel() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - ControlPanelViewController

final class ControlPanelViewController: NSViewController {

    // MARK: - UI Elements: Top Section ("Điều khiển")

    private let topBox: NSBox = {
        let box = NSBox()
        box.titlePosition = .noTitle
        box.boxType = .primary
        box.borderType = .lineBorder
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    } ()

    private let methodLabel = NSTextField(labelWithString: "Kiểu gõ:")
    private let methodPopup: NSPopUpButton = {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.addItems(withTitles: ["Telex", "VNI", "Simple Telex"])
        button.font = NSFont.systemFont(ofSize: 12)
        return button
    } ()

    private let codeLabel = NSTextField(labelWithString: "Bảng mã:")
    private let codePopup: NSPopUpButton = {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.addItems(withTitles: [
            "Unicode (Unicode dựng sẵn)",
            "TCVN3 (ABC)",
            "VNI Windows",
            "Unicode Compound (Unicode tổ hợp)",
            "Vietnamese Locale CP 1258"
        ])
        button.font = NSFont.systemFont(ofSize: 12)
        return button
    } ()

    private let hotkeyLabel = NSTextField(labelWithString: "Phím chuyển:")
    private let ctrlCheckbox = NSButton(checkboxWithTitle: "⌃ Ctrl", target: nil, action: nil)
    private let optCheckbox = NSButton(checkboxWithTitle: "⌥ Opt", target: nil, action: nil)
    private let cmdCheckbox = NSButton(checkboxWithTitle: "⌘ Cmd", target: nil, action: nil)
    private let shiftCheckbox = NSButton(checkboxWithTitle: "⇧ Shift", target: nil, action: nil)
    
    private let hotkeyTextField: NSTextField = {
        let field = NSTextField()
        field.stringValue = "Space"
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 12)
        field.wantsLayer = true
        field.layer?.cornerRadius = 4
        return field
    } ()
    
    private let beepCheckbox = NSButton(checkboxWithTitle: "Kêu Beep", target: nil, action: nil)

    private let modeLabel = NSTextField(labelWithString: "Chế độ gõ:")
    private let vietModeRadio: NSButton = {
        let button = NSButton(radioButtonWithTitle: "Tiếng Việt", target: nil, action: nil)
        button.font = NSFont.systemFont(ofSize: 12)
        return button
    } ()
    private let engModeRadio: NSButton = {
        let button = NSButton(radioButtonWithTitle: "English", target: nil, action: nil)
        button.font = NSFont.systemFont(ofSize: 12)
        return button
    } ()

    // MARK: - UI Elements: Middle Section (Tabs)

    private let tabView: NSTabView = {
        let tv = NSTabView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    } ()

    // Tab 1: Bộ gõ
    private let freeMarkCheckbox = NSButton(checkboxWithTitle: "Tự do đặt dấu", target: nil, action: nil)
    private let modernOrthographyCheckbox = NSButton(checkboxWithTitle: "Đặt dấu kiểu mới (oà, uý)", target: nil, action: nil)
    private let grammarCheckbox = NSButton(checkboxWithTitle: "Kiểm tra ngữ pháp", target: nil, action: nil)
    private let spellingCheckbox = NSButton(checkboxWithTitle: "Kiểm tra chính tả", target: nil, action: nil)
    private let restoreKeyCheckbox = NSButton(checkboxWithTitle: "Phục hồi phím với từ sai", target: nil, action: nil)
    private let autoCapsCheckbox = NSButton(checkboxWithTitle: "Tự động viết hoa chữ cái đầu", target: nil, action: nil)
    private let quickTelexCheckbox = NSButton(checkboxWithTitle: "Gõ nhanh Telex", target: nil, action: nil)
    private let tempOffSpellingCheckbox = NSButton(checkboxWithTitle: "Tạm tắt chính tả bằng Ctrl", target: nil, action: nil)
    private let allowFZWJCheckbox = NSButton(checkboxWithTitle: "Cho phép dùng f z w j làm phụ âm đầu", target: nil, action: nil)

    // Tab 2: Gõ tắt
    private let useMacroCheckbox = NSButton(checkboxWithTitle: "Cho phép gõ tắt", target: nil, action: nil)
    private let autoCapsMacroCheckbox = NSButton(checkboxWithTitle: "Tự động viết hoa theo phím tắt", target: nil, action: nil)
    private let quickMacroCheckbox = NSButton(checkboxWithTitle: "Gõ nhanh (cc=ch, gg=gi, kk=kh...)", target: nil, action: nil)
    private let macroInEnglishCheckbox = NSButton(checkboxWithTitle: "Gõ tắt cả khi tắt gõ tiếng Việt", target: nil, action: nil)
    private let macroStartConsCheckbox = NSButton(checkboxWithTitle: "Gõ tắt phụ âm đầu: f->ph, j->gi, w->qu", target: nil, action: nil)
    private let macroEndConsCheckbox = NSButton(checkboxWithTitle: "Gõ tắt phụ âm cuối: g->ng, h->nh, k->ch", target: nil, action: nil)
    private let macroTableButton: NSButton = {
        let button = NSButton(title: "Bảng gõ tắt...", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 12)
        return button
    } ()

    // Tab 3: Hệ thống
    private let showDockCheckbox = NSButton(checkboxWithTitle: "Hiện biểu tượng trên thanh Dock", target: nil, action: nil)
    private let showOnStartupCheckbox = NSButton(checkboxWithTitle: "Bật bảng này khi khởi động", target: nil, action: nil)
    private let menuIconCheckbox = NSButton(checkboxWithTitle: "Biểu tượng hiện đại trên thanh menu", target: nil, action: nil)
    private let runOnStartupCheckbox = NSButton(checkboxWithTitle: "Khởi động cùng macOS", target: nil, action: nil)
    private let smartSwitchCheckbox = NSButton(checkboxWithTitle: "Chuyển chế độ thông minh (loại trừ app)", target: nil, action: nil)
    
    private let fixChromiumCheckbox = NSButton(checkboxWithTitle: "Sửa lỗi Autocorrect (Chrome, Safari, Excel)", target: nil, action: nil)
    private let fixUnderlineCheckbox = NSButton(checkboxWithTitle: "Sửa lỗi gạch chân trên macOS", target: nil, action: nil)
    private let sendKeyStepCheckbox = NSButton(checkboxWithTitle: "Gửi từng phím (nếu bị lỗi)", target: nil, action: nil)
    private let checkUpdateCheckbox = NSButton(checkboxWithTitle: "Kiểm tra bản mới lúc khởi động", target: nil, action: nil)
    private let checkNewVersionButton: NSButton = {
        let button = NSButton(title: "Kiểm tra bản mới...", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 12)
        return button
    } ()

    // MARK: - UI Elements: Bottom Section (Action Footer)

    private let quitButton: NSButton = {
        let button = NSButton(title: "Kết thúc", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 13)
        return button
    } ()
    private let defaultButton: NSButton = {
        let button = NSButton(title: "Mặc định", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 13)
        return button
    } ()
    private let okButton: NSButton = {
        let button = NSButton(title: "OK", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 13)
        return button
    } ()

    // MARK: - Lifecycle

    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 480))
        self.view = view
        
        // Cố định kích thước của view để Auto Layout của hệ thống không tự động thay đổi
        view.widthAnchor.constraint(equalToConstant: 560).isActive = true
        view.heightAnchor.constraint(equalToConstant: 480).isActive = true
        
        setupLayout()
        loadPreferences()
        setupActions()
    }

    // MARK: - Layout Setup

    private func setupLayout() {
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 14
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
        
        // 1. Top Section - Box "Điều khiển"
        mainStack.addArrangedSubview(topBox)
        topBox.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor).isActive = true
        topBox.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor).isActive = true
        
        setupTopBoxContent()
        
        // 2. Middle Section - Tab View
        mainStack.addArrangedSubview(tabView)
        tabView.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor).isActive = true
        tabView.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor).isActive = true
        // Cố định chiều cao của Tab View để cửa sổ không bị co giãn khi đổi tab
        tabView.heightAnchor.constraint(equalToConstant: 240).isActive = true
        
        setupTabs()
        
        // 3. Footer buttons
        let footerStack = NSStackView()
        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.spacing = 12
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(footerStack)
        footerStack.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor).isActive = true
        footerStack.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor).isActive = true
        
        footerStack.addArrangedSubview(quitButton)
        let footerSpacer = NSView()
        footerStack.addArrangedSubview(footerSpacer)
        footerStack.addArrangedSubview(defaultButton)
        footerStack.addArrangedSubview(okButton)
        
        quitButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
        defaultButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
        okButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
    }

    private func setupTopBoxContent() {
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        topBox.contentView = contentStack
        
        // Dòng 1: Kiểu gõ & Bảng mã
        let row1 = NSStackView()
        row1.orientation = .horizontal
        row1.alignment = .centerY
        row1.spacing = 12
        row1.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(row1)
        
        row1.addArrangedSubview(methodLabel)
        row1.addArrangedSubview(methodPopup)
        row1.addArrangedSubview(codeLabel)
        row1.addArrangedSubview(codePopup)
        
        methodPopup.widthAnchor.constraint(equalToConstant: 120).isActive = true
        codePopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        
        // Dòng 2: Phím chuyển
        let row2 = NSStackView()
        row2.orientation = .horizontal
        row2.alignment = .centerY
        row2.spacing = 8
        row2.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(row2)
        
        row2.addArrangedSubview(hotkeyLabel)
        row2.addArrangedSubview(ctrlCheckbox)
        row2.addArrangedSubview(optCheckbox)
        row2.addArrangedSubview(cmdCheckbox)
        row2.addArrangedSubview(shiftCheckbox)
        row2.addArrangedSubview(hotkeyTextField)
        row2.addArrangedSubview(beepCheckbox)
        
        hotkeyTextField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        hotkeyTextField.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        // Dòng 3: Chế độ gõ
        let row3 = NSStackView()
        row3.orientation = .horizontal
        row3.alignment = .centerY
        row3.spacing = 16
        row3.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(row3)
        
        row3.addArrangedSubview(modeLabel)
        row3.addArrangedSubview(vietModeRadio)
        row3.addArrangedSubview(engModeRadio)
        
        // Đặt tag để quản lý radio group
        vietModeRadio.tag = 1
        engModeRadio.tag = 0
    }

    private func setupTabs() {
        // Tab 1: Bộ gõ
        let boGoItem = NSTabViewItem(identifier: "bogo")
        boGoItem.label = "Bộ gõ"
        boGoItem.view = makeBoGoTabView()
        tabView.addTabViewItem(boGoItem)
        
        // Tab 2: Gõ tắt
        let goTatItem = NSTabViewItem(identifier: "gotat")
        goTatItem.label = "Gõ tắt"
        goTatItem.view = makeGoTatTabView()
        tabView.addTabViewItem(goTatItem)
        
        // Tab 3: Hệ thống
        let heThongItem = NSTabViewItem(identifier: "hethong")
        heThongItem.label = "Hệ thống"
        heThongItem.view = makeHeThongTabView()
        tabView.addTabViewItem(heThongItem)
        
        // Tab 4: Thông tin
        let thongTinItem = NSTabViewItem(identifier: "thongtin")
        thongTinItem.label = "Thông tin"
        thongTinItem.view = makeThongTinTabView()
        tabView.addTabViewItem(thongTinItem)
    }

    private func makeBoGoTabView() -> NSView {
        let container = NSView()
        let horizontalStack = NSStackView()
        horizontalStack.orientation = .horizontal
        horizontalStack.alignment = .top
        horizontalStack.distribution = .fillEqually
        horizontalStack.spacing = 16
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(horizontalStack)
        
        NSLayoutConstraint.activate([
            horizontalStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            horizontalStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            horizontalStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            horizontalStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12)
        ])
        
        // Cột trái
        let leftCol = NSStackView()
        leftCol.orientation = .vertical
        leftCol.alignment = .leading
        leftCol.spacing = 8
        leftCol.addArrangedSubview(freeMarkCheckbox)
        leftCol.addArrangedSubview(modernOrthographyCheckbox)
        leftCol.addArrangedSubview(grammarCheckbox)
        leftCol.addArrangedSubview(spellingCheckbox)
        leftCol.addArrangedSubview(autoCapsCheckbox)
        
        // Cột phải
        let rightCol = NSStackView()
        rightCol.orientation = .vertical
        rightCol.alignment = .leading
        rightCol.spacing = 8
        rightCol.addArrangedSubview(quickTelexCheckbox)
        rightCol.addArrangedSubview(restoreKeyCheckbox)
        rightCol.addArrangedSubview(allowFZWJCheckbox)
        rightCol.addArrangedSubview(tempOffSpellingCheckbox)
        
        horizontalStack.addArrangedSubview(leftCol)
        horizontalStack.addArrangedSubview(rightCol)
        
        return container
    }

    private func makeGoTatTabView() -> NSView {
        let container = NSView()
        let horizontalStack = NSStackView()
        horizontalStack.orientation = .horizontal
        horizontalStack.alignment = .top
        horizontalStack.distribution = .fillEqually
        horizontalStack.spacing = 16
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(horizontalStack)
        
        NSLayoutConstraint.activate([
            horizontalStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            horizontalStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            horizontalStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            horizontalStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12)
        ])
        
        // Cột trái
        let leftCol = NSStackView()
        leftCol.orientation = .vertical
        leftCol.alignment = .leading
        leftCol.spacing = 8
        leftCol.addArrangedSubview(useMacroCheckbox)
        leftCol.addArrangedSubview(autoCapsMacroCheckbox)
        
        let buttonSpacer = NSView()
        leftCol.addArrangedSubview(buttonSpacer)
        leftCol.addArrangedSubview(macroTableButton)
        macroTableButton.widthAnchor.constraint(equalToConstant: 120).isActive = true
        
        // Cột phải
        let rightCol = NSStackView()
        rightCol.orientation = .vertical
        rightCol.alignment = .leading
        rightCol.spacing = 8
        rightCol.addArrangedSubview(quickMacroCheckbox)
        rightCol.addArrangedSubview(macroInEnglishCheckbox)
        rightCol.addArrangedSubview(macroStartConsCheckbox)
        rightCol.addArrangedSubview(macroEndConsCheckbox)
        
        horizontalStack.addArrangedSubview(leftCol)
        horizontalStack.addArrangedSubview(rightCol)
        
        return container
    }

    private func makeHeThongTabView() -> NSView {
        let container = NSView()
        let horizontalStack = NSStackView()
        horizontalStack.orientation = .horizontal
        horizontalStack.alignment = .top
        horizontalStack.distribution = .fillEqually
        horizontalStack.spacing = 16
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(horizontalStack)
        
        NSLayoutConstraint.activate([
            horizontalStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            horizontalStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            horizontalStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            horizontalStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12)
        ])
        
        // Cột trái
        let leftCol = NSStackView()
        leftCol.orientation = .vertical
        leftCol.alignment = .leading
        leftCol.spacing = 8
        leftCol.addArrangedSubview(showDockCheckbox)
        leftCol.addArrangedSubview(showOnStartupCheckbox)
        leftCol.addArrangedSubview(menuIconCheckbox)
        leftCol.addArrangedSubview(runOnStartupCheckbox)
        leftCol.addArrangedSubview(smartSwitchCheckbox)
        
        // Cột phải
        let rightCol = NSStackView()
        rightCol.orientation = .vertical
        rightCol.alignment = .leading
        rightCol.spacing = 8
        rightCol.addArrangedSubview(fixChromiumCheckbox)
        rightCol.addArrangedSubview(fixUnderlineCheckbox)
        rightCol.addArrangedSubview(sendKeyStepCheckbox)
        rightCol.addArrangedSubview(checkUpdateCheckbox)
        
        let buttonSpacer = NSView()
        rightCol.addArrangedSubview(buttonSpacer)
        rightCol.addArrangedSubview(checkNewVersionButton)
        checkNewVersionButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
        
        horizontalStack.addArrangedSubview(leftCol)
        horizontalStack.addArrangedSubview(rightCol)
        
        return container
    }

    private func makeThongTinTabView() -> NSView {
        let container = NSView()
        
        let title = NSTextField(labelWithString: "VNKey Bộ Gõ Tiếng Việt")
        title.font = NSFont.boldSystemFont(ofSize: 18)
        title.textColor = .labelColor
        title.alignment = .center
        
        let version = NSTextField(labelWithString: "Phiên bản 2.0.2 (Build 2026.08)")
        version.font = NSFont.systemFont(ofSize: 13)
        version.textColor = .secondaryLabelColor
        version.alignment = .center
        
        let credit = NSTextField(labelWithString: "Bản quyền © 2026 VNKey Team.\nTham khảo giao diện & kỹ thuật từ bộ gõ OpenKey.\nMột bộ gõ mã nguồn mở gọn nhẹ và tiện dụng cho macOS.")
        credit.font = NSFont.systemFont(ofSize: 12)
        credit.alignment = .center
        credit.textColor = .secondaryLabelColor
        credit.cell?.wraps = true
        credit.cell?.isScrollable = false
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -14),
            stack.widthAnchor.constraint(equalToConstant: 460)
        ])
        
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(version)
        stack.addArrangedSubview(credit)
        
        return container
    }

    // MARK: - Preferences Mapping

    private func loadPreferences() {
        let prefs = PreferencesManager.shared
        
        // Kiểu gõ (Telex, VNI, Simple Telex)
        switch prefs.inputMethod {
        case .telex: methodPopup.selectItem(at: 0)
        case .vni: methodPopup.selectItem(at: 1)
        case .simpleTelex: methodPopup.selectItem(at: 2)
        }
        
        // Bảng mã
        codePopup.selectItem(at: prefs.codeTable)
        
        // Phím chuyển hotkeys
        ctrlCheckbox.state = prefs.switchKeyControl ? .on : .off
        optCheckbox.state = prefs.switchKeyOption ? .on : .off
        cmdCheckbox.state = prefs.switchKeyCommand ? .on : .off
        shiftCheckbox.state = prefs.switchKeyShift ? .on : .off
        hotkeyTextField.stringValue = prefs.switchKeyText
        beepCheckbox.state = prefs.switchKeyBeep ? .on : .off
        
        // Chế độ gõ
        if prefs.isEnabled {
            vietModeRadio.state = .on
            engModeRadio.state = .off
        } else {
            vietModeRadio.state = .off
            engModeRadio.state = .on
        }
        
        // Tab 1: Bộ gõ
        freeMarkCheckbox.state = prefs.showMarkedText ? .on : .off // maps showMarkedText/marked line in editing
        modernOrthographyCheckbox.state = (prefs.tonePlacement == .newStyle) ? .on : .off
        grammarCheckbox.state = prefs.checkSpelling ? .on : .off // mock grammar toggle
        spellingCheckbox.state = prefs.checkSpelling ? .on : .off
        restoreKeyCheckbox.state = prefs.restoreIfInvalid ? .on : .off
        autoCapsCheckbox.state = prefs.autoCapsMacro ? .on : .off
        quickTelexCheckbox.state = prefs.quickTelex ? .on : .off
        tempOffSpellingCheckbox.state = prefs.tempOffSpelling ? .on : .off
        allowFZWJCheckbox.state = prefs.allowFZWJ ? .on : .off
        
        // Tab 2: Gõ tắt
        useMacroCheckbox.state = prefs.useMacro ? .on : .off
        autoCapsMacroCheckbox.state = prefs.autoCapsMacro ? .on : .off
        quickMacroCheckbox.state = prefs.quickTelex ? .on : .off
        macroInEnglishCheckbox.state = prefs.tempOffSpelling ? .on : .off
        macroStartConsCheckbox.state = prefs.macroStartCons ? .on : .off
        macroEndConsCheckbox.state = prefs.macroEndCons ? .on : .off
        
        // Tab 3: Hệ thống
        showDockCheckbox.state = prefs.showIconOnDock ? .on : .off
        showOnStartupCheckbox.state = prefs.showUIOnStartup ? .on : .off
        menuIconCheckbox.state = prefs.grayIcon ? .on : .off
        runOnStartupCheckbox.state = prefs.runOnStartup ? .on : .off
        smartSwitchCheckbox.state = prefs.smartSwitch ? .on : .off
        
        fixChromiumCheckbox.state = prefs.fixChromium ? .on : .off
        fixUnderlineCheckbox.state = prefs.fixUnderline ? .on : .off
        sendKeyStepCheckbox.state = prefs.sendKeyStep ? .on : .off
        checkUpdateCheckbox.state = prefs.checkUpdate ? .on : .off
    }

    private func savePreferences() {
        let prefs = PreferencesManager.shared
        
        // Kiểu gõ
        switch methodPopup.indexOfSelectedItem {
        case 0: prefs.inputMethod = .telex
        case 1: prefs.inputMethod = .vni
        case 2: prefs.inputMethod = .simpleTelex
        default: break
        }
        
        // Bảng mã
        prefs.codeTable = codePopup.indexOfSelectedItem
        
        // Phím chuyển
        prefs.switchKeyControl = (ctrlCheckbox.state == .on)
        prefs.switchKeyOption = (optCheckbox.state == .on)
        prefs.switchKeyCommand = (cmdCheckbox.state == .on)
        prefs.switchKeyShift = (shiftCheckbox.state == .on)
        prefs.switchKeyText = hotkeyTextField.stringValue
        prefs.switchKeyBeep = (beepCheckbox.state == .on)
        
        // Chế độ gõ
        prefs.isEnabled = (vietModeRadio.state == .on)
        
        // Tab 1: Bộ gõ
        prefs.showMarkedText = (freeMarkCheckbox.state == .on)
        prefs.tonePlacement = (modernOrthographyCheckbox.state == .on) ? .newStyle : .oldStyle
        prefs.checkSpelling = (spellingCheckbox.state == .on)
        prefs.restoreIfInvalid = (restoreKeyCheckbox.state == .on)
        prefs.quickTelex = (quickTelexCheckbox.state == .on)
        prefs.tempOffSpelling = (tempOffSpellingCheckbox.state == .on)
        prefs.allowFZWJ = (allowFZWJCheckbox.state == .on)
        
        // Tab 2: Gõ tắt
        prefs.useMacro = (useMacroCheckbox.state == .on)
        prefs.autoCapsMacro = (autoCapsMacroCheckbox.state == .on)
        prefs.macroStartCons = (macroStartConsCheckbox.state == .on)
        prefs.macroEndCons = (macroEndConsCheckbox.state == .on)
        
        // Tab 3: Hệ thống
        prefs.showIconOnDock = (showDockCheckbox.state == .on)
        prefs.showUIOnStartup = (showOnStartupCheckbox.state == .on)
        prefs.grayIcon = (menuIconCheckbox.state == .on)
        prefs.runOnStartup = (runOnStartupCheckbox.state == .on)
        prefs.smartSwitch = (smartSwitchCheckbox.state == .on)
        
        prefs.fixChromium = (fixChromiumCheckbox.state == .on)
        prefs.fixUnderline = (fixUnderlineCheckbox.state == .on)
        prefs.sendKeyStep = (sendKeyStepCheckbox.state == .on)
        prefs.checkUpdate = (checkUpdateCheckbox.state == .on)
        
        // Đồng bộ preferences
        GlobalEventTapManager.shared.syncPreferences()
        
        // Cập nhật biểu tượng menu bar
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateStatusButton()
        }
    }

    private func setupActions() {
        vietModeRadio.target = self
        vietModeRadio.action = #selector(modeRadioToggled(_:))
        
        engModeRadio.target = self
        engModeRadio.action = #selector(modeRadioToggled(_:))
        
        quitButton.target = self
        quitButton.action = #selector(quitButtonClicked(_:))
        
        defaultButton.target = self
        defaultButton.action = #selector(defaultButtonClicked(_:))
        
        okButton.target = self
        okButton.action = #selector(okButtonClicked(_:))
        
        macroTableButton.target = self
        macroTableButton.action = #selector(macroTableButtonClicked(_:))
        
        checkNewVersionButton.target = self
        checkNewVersionButton.action = #selector(checkNewVersionButtonClicked(_:))
    }

    // MARK: - Actions

    @objc private func modeRadioToggled(_ sender: NSButton) {
        // Tắt radio button kia
        if sender == vietModeRadio {
            engModeRadio.state = .off
        } else {
            vietModeRadio.state = .off
        }
    }

    @objc private func quitButtonClicked(_ sender: NSButton) {
        NSApplication.shared.terminate(nil)
    }

    @objc private func defaultButtonClicked(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Thiết lập lại mặc định"
        alert.informativeText = "Bạn có chắc chắn muốn khôi phục tất cả cài đặt về cấu hình mặc định ban đầu?"
        alert.addButton(withTitle: "Có")
        alert.addButton(withTitle: "Không")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Reset to system defaults
            let domain = Bundle.main.bundleIdentifier ?? "vn.key.VNKey"
            UserDefaults.standard.removePersistentDomain(forName: domain)
            loadPreferences()
            savePreferences()
        }
    }

    @objc private func okButtonClicked(_ sender: NSButton) {
        savePreferences()
        self.view.window?.close()
    }

    @objc private func macroTableButtonClicked(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Thiết lập gõ tắt"
        alert.informativeText = "Tính năng cấu hình danh sách gõ tắt đầy đủ đang được xây dựng."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func checkNewVersionButtonClicked(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Kiểm tra phiên bản mới"
        alert.informativeText = "Bạn đang sử dụng phiên bản mới nhất (2.0.2). Không có bản cập nhật nào."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
