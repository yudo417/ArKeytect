//
//  ButtonDetector.swift
//  ProControlerForMac
//
//  コントローラーボタンの動的検出
//

import Foundation
import GameController
import Combine

/// 検出されたボタン情報
struct DetectedButton: Identifiable, Codable, Hashable {
    let id: String  // 一意の識別子（例: "button_A", "dpad_down"）
    var displayName: String  // 表示名（ユーザーが編集可能）
    let buttonType: ButtonType  // ボタンの種類
    
    enum ButtonType: String, Codable {
        case button = "ボタン"
        case dpad = "D-Pad"
        case shoulder = "バンパー/トリガー"
        case stick = "スティックボタン"
        case menu = "メニュー"
        case unknown = "その他"
    }
    
    /// SF Symbolsのアイコン名
    var icon: String {
        // idに基づいてアイコンを返す
        if id.contains("button_A") { return "a.circle.fill" }
        if id.contains("button_B") { return "b.circle.fill" }
        if id.contains("button_X") { return "x.circle.fill" }
        if id.contains("button_Y") { return "y.circle.fill" }
        if id.contains("leftShoulder") { return "l.button.roundedbottom.horizontal.fill" }
        if id.contains("rightShoulder") { return "r.button.roundedbottom.horizontal.fill" }
        if id.contains("leftTrigger") { return "zl.button.roundedtop.horizontal.fill" }
        if id.contains("rightTrigger") { return "zr.button.roundedtop.horizontal.fill" }
        if id.contains("leftThumbstickButton") { return "l.joystick.press.down.fill" }
        if id.contains("rightThumbstickButton") { return "r.joystick.press.down.fill" }
        if id.contains("dpad") {
            if id.contains("up") { return "dpad.up.filled" }
            if id.contains("down") { return "dpad.down.filled" }
            if id.contains("left") { return "dpad.left.filled" }
            if id.contains("right") { return "dpad.right.filled" }
        }
        if id.contains("buttonMenu") { return "plus.circle.fill" }
        if id.contains("buttonOptions") { return "minus.circle.fill" }  // Screenshotボタン
        if id.contains("buttonHome") { return "house.circle.fill" }
        if id.contains("buttonCapture") { return "camera.circle.fill" }
        return "circle.fill"
    }
    
    /// カテゴリ（セクション分け用）
    var category: String {
        buttonType.rawValue
    }
}

/// ボタン検出器
class ButtonDetector: ObservableObject {
    // MARK: - Published Properties
    
    /// 登録されているボタン一覧
    @Published var registeredButtons: [DetectedButton] = []
    
    /// ボタン検出モードが有効かどうか
    @Published var isDetectionMode: Bool = false
    
    /// 検出中のメッセージ
    @Published var detectionMessage: String = ""
    
    /// 最後に検出されたボタン
    @Published var lastDetectedButton: DetectedButton?
    
    /// 登録されたショートカット一覧
    @Published var shortcuts: [DynamicShortcutBinding] = []
    
    /// 最後に押されたボタンID（ショートカット実行用）
    @Published var lastPressedButtonId: String?
    
    /// ボタンイベント通知用のクロージャ (buttonId, isPressed)
    var onButtonEvent: ((String, Bool) -> Void)?
    
    // MARK: - Private Properties
    
    private var controller: GCController?
    private var lastButtonStates: [String: Bool] = [:] // ボタン状態のキャッシュ
    private let storageKey = "RegisteredButtons"
    private let shortcutsStorageKey = "DynamicShortcutBindings"
    
    // MARK: - Default Pro Controller Buttons
    
    /// Nintendo Switch Pro Controllerのデフォルトボタン一覧
    /// ⚠️ 重要：buttonOptions（-/Screenshot）とbuttonHome（Home）は完全に別のボタン
    static let defaultProControllerButtons: [DetectedButton] = [
        // アクションボタン
        DetectedButton(id: "button_A", displayName: "A", buttonType: .button),
        DetectedButton(id: "button_B", displayName: "B", buttonType: .button),
        DetectedButton(id: "button_X", displayName: "X", buttonType: .button),
        DetectedButton(id: "button_Y", displayName: "Y", buttonType: .button),
        
        // D-Pad
        DetectedButton(id: "dpad_up", displayName: "↑", buttonType: .dpad),
        DetectedButton(id: "dpad_down", displayName: "↓", buttonType: .dpad),
        DetectedButton(id: "dpad_left", displayName: "←", buttonType: .dpad),
        DetectedButton(id: "dpad_right", displayName: "→", buttonType: .dpad),
        
        // バンパー/トリガー
        DetectedButton(id: "leftShoulder", displayName: "L", buttonType: .shoulder),
        DetectedButton(id: "rightShoulder", displayName: "R", buttonType: .shoulder),
        DetectedButton(id: "leftTrigger", displayName: "ZL", buttonType: .shoulder),
        DetectedButton(id: "rightTrigger", displayName: "ZR", buttonType: .shoulder),
        
        // スティックボタン
        DetectedButton(id: "leftThumbstickButton", displayName: "左スティック押し込み", buttonType: .stick),
        DetectedButton(id: "rightThumbstickButton", displayName: "右スティック押し込み", buttonType: .stick),
        
        // メニューボタン（3つすべて別々のボタン）
        DetectedButton(id: "buttonMenu", displayName: "+", buttonType: .menu),
        DetectedButton(id: "buttonOptions", displayName: "-", buttonType: .menu),
        DetectedButton(id: "buttonHome", displayName: "Home", buttonType: .menu),
        DetectedButton(id: "buttonCapture", displayName: "Capture", buttonType: .menu)
    ]
    
    // MARK: - Initialization
    
    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self = self else { return }
            self.loadButtons()
            self.loadShortcuts()
            self.registerDefaultButtons()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.setupControllerNotifications() }
    }
    
    /// デフォルトのプロコンボタンを登録
    private func registerDefaultButtons() {
        var needsSave = false
        
        for defaultButton in Self.defaultProControllerButtons {
            // 既に登録されていない場合のみ追加
            if !registeredButtons.contains(where: { $0.id == defaultButton.id }) {
                registeredButtons.append(defaultButton)
                needsSave = true
            }
        }
        
        if needsSave {
            saveButtons()
        }
    }
    
    // MARK: - Controller Setup
    
    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        // 既存のコントローラーをチェック
        if let existingController = GCController.controllers().first {
            setupController(existingController)
        }
    }
    
    @objc private func controllerDidConnect(notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        DispatchQueue.main.async {
            self.setupController(controller)
        }
    }
    
    private func setupController(_ controller: GCController) {
        self.controller = controller
        controller.handlerQueue = DispatchQueue.main
        
        if let gamepad = controller.extendedGamepad {
            blockSystemEvents(for: gamepad)
            if let microGamepad = controller.microGamepad {
                microGamepad.allowsRotation = false
                microGamepad.reportsAbsoluteDpadValues = false
            }
        }
        
        startMonitoringAllButtons()
    }
    
    /// システムイベントのブロック設定
    private func blockSystemEvents(for gamepad: GCExtendedGamepad) {
        // Homeボタンをブロック（ゲームアプリ起動を防ぐ）
        if let homeButton = gamepad.buttonHome {
            homeButton.pressedChangedHandler = { [weak self] button, value, pressed in
                if pressed {
                    // ショートカットが登録されていれば実行
                    if let shortcut = self?.shortcuts.first(where: { $0.buttonId == "buttonHome" && $0.isEnabled }) {
                        self?.executeShortcut(shortcut)
                    }
                }
                // イベントを消費してシステムに渡さない
            }
        }
    }
    
    // MARK: - Detection Mode
    
    /// ボタン検出モードを開始
    func startDetection() {
        isDetectionMode = true
        detectionMessage = "コントローラーのボタンを押してください..."
        lastDetectedButton = nil
        
        // 既にstartMonitoringAllButtons()はsetupController()で呼ばれているため、
        // ここでは検出モードフラグを立てるだけでOK
    }
    
    /// ボタン検出モードを終了
    func stopDetection() {
        isDetectionMode = false
        detectionMessage = ""
    }
    
    private func startMonitoringAllButtons() {
        guard let gamepad = controller?.extendedGamepad else {
            detectionMessage = "コントローラーが接続されていません"
            return
        }
        
        // すべてのボタンの変更を監視
        gamepad.valueChangedHandler = { [weak self] gamepad, element in
            guard let self = self else { return }
            
            // ボタン状態の全チェックとイベント通知（レイヤー切り替え用）
            self.checkAllButtons(gamepad: gamepad)
            
            // 検出モードの場合はボタンを検出
            if self.isDetectionMode {
                self.detectButton(from: gamepad, element: element)
                return  // 検出モード中はショートカット実行しない
            }
            
            // 通常モード: ショートカット実行
            self.handleButtonPressForShortcut(from: gamepad, element: element)
        }
    }
    
    /// 全ボタンの状態をチェックし、変化があれば通知
    private func checkAllButtons(gamepad: GCExtendedGamepad) {
        let buttons: [(String, GCControllerButtonInput?)] = [
            ("button_A", gamepad.buttonA),
            ("button_B", gamepad.buttonB),
            ("button_X", gamepad.buttonX),
            ("button_Y", gamepad.buttonY),
            ("leftShoulder", gamepad.leftShoulder),
            ("rightShoulder", gamepad.rightShoulder),
            ("leftTrigger", gamepad.leftTrigger),
            ("rightTrigger", gamepad.rightTrigger),
            ("leftThumbstickButton", gamepad.leftThumbstickButton),
            ("rightThumbstickButton", gamepad.rightThumbstickButton),
            ("dpad_up", gamepad.dpad.up),
            ("dpad_down", gamepad.dpad.down),
            ("dpad_left", gamepad.dpad.left),
            ("dpad_right", gamepad.dpad.right),
            ("buttonMenu", gamepad.buttonMenu),
            ("buttonOptions", gamepad.buttonOptions),
            ("buttonHome", gamepad.buttonHome)
        ]
        
        for (id, buttonInput) in buttons {
            guard let buttonInput = buttonInput else { continue }
            let isPressed = buttonInput.isPressed
            
            // 状態が変わった場合のみ通知
            if lastButtonStates[id] != isPressed {
                lastButtonStates[id] = isPressed
                onButtonEvent?(id, isPressed)
            }
        }
    }
    
    /// HID 由来のボタンイベント（Capture のみ。view 更新外で実行するため asyncAfter）
    func handleExternalButtonEvent(buttonId: String, pressed: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) { [weak self] in
            guard let self = self else { return }
            if self.lastButtonStates[buttonId] == pressed { return }
            self.lastButtonStates[buttonId] = pressed
            self.onButtonEvent?(buttonId, pressed)
            guard pressed else { return }
            guard let shortcut = self.shortcuts.first(where: { $0.buttonId == buttonId && $0.isEnabled }) else { return }
            self.executeShortcut(shortcut)
            self.lastPressedButtonId = buttonId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.lastPressedButtonId = nil }
        }
    }
    
    /// ショートカット実行のためのボタン押下処理
    private func handleButtonPressForShortcut(from gamepad: GCExtendedGamepad, element: GCControllerElement) {
        guard ControllerEnabledState.shared.isControllerEnabled else { return }
        guard let buttonId = getButtonId(from: gamepad, element: element) else {
            // ボタンが押されていない場合（リリース時）は何もしない
            return
        }
        
        // そのボタンにショートカットが登録されているかチェック
        guard let shortcut = shortcuts.first(where: { $0.buttonId == buttonId && $0.isEnabled }) else {
            // ショートカット未登録の場合は何もしない（イベントを素通しする）
            return
        }
        
        executeShortcut(shortcut)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
            self.lastPressedButtonId = buttonId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.lastPressedButtonId = nil }
        }
    }
    
    /// ボタンIDを取得
    private func getButtonId(from gamepad: GCExtendedGamepad, element: GCControllerElement) -> String? {
        // ボタンが押された場合のみIDを返す
        if element == gamepad.buttonA, gamepad.buttonA.isPressed { return "button_A" }
        if element == gamepad.buttonB, gamepad.buttonB.isPressed { return "button_B" }
        if element == gamepad.buttonX, gamepad.buttonX.isPressed { return "button_X" }
        if element == gamepad.buttonY, gamepad.buttonY.isPressed { return "button_Y" }
        
        if element == gamepad.leftShoulder, gamepad.leftShoulder.isPressed { return "leftShoulder" }
        if element == gamepad.rightShoulder, gamepad.rightShoulder.isPressed { return "rightShoulder" }
        if element == gamepad.leftTrigger, gamepad.leftTrigger.isPressed { return "leftTrigger" }
        if element == gamepad.rightTrigger, gamepad.rightTrigger.isPressed { return "rightTrigger" }
        
        if let leftStick = gamepad.leftThumbstickButton, element == leftStick, leftStick.isPressed {
            return "leftThumbstickButton"
        }
        if let rightStick = gamepad.rightThumbstickButton, element == rightStick, rightStick.isPressed {
            return "rightThumbstickButton"
        }
        
        // D-Pad全体の要素チェック
        if element == gamepad.dpad {
            if gamepad.dpad.up.isPressed { return "dpad_up" }
            if gamepad.dpad.down.isPressed { return "dpad_down" }
            if gamepad.dpad.left.isPressed { return "dpad_left" }
            if gamepad.dpad.right.isPressed { return "dpad_right" }
        }
        
        // D-Padの個別方向チェック（上記で検出できない場合のフォールバック）
        if element == gamepad.dpad.up, gamepad.dpad.up.isPressed { return "dpad_up" }
        if element == gamepad.dpad.down, gamepad.dpad.down.isPressed { return "dpad_down" }
        if element == gamepad.dpad.left, gamepad.dpad.left.isPressed { return "dpad_left" }
        if element == gamepad.dpad.right, gamepad.dpad.right.isPressed { return "dpad_right" }
        
        // メニュー/システムボタン
        if element == gamepad.buttonMenu, gamepad.buttonMenu.isPressed { return "buttonMenu" }
        if let options = gamepad.buttonOptions, element == options, options.isPressed { return "buttonOptions" }
        if let home = gamepad.buttonHome, element == home, home.isPressed { return "buttonHome" }
        
        return nil
    }
    
    /// ショートカットを実行
    private func executeShortcut(_ shortcut: DynamicShortcutBinding) {
        guard ControllerEnabledState.shared.isControllerEnabled else { return }
        let keyCode = CGKeyCode(shortcut.keyCode)
        
        // 修飾キーを取得
        var flags: CGEventFlags = []
        var modifierKeyCodes: [CGKeyCode] = [] // 修飾キーのキーコードを記録
        
        if let mods = shortcut.modifierFlags {
            if mods.contains(.control) {
                flags.insert(.maskControl)
                modifierKeyCodes.append(59) // Control (左)
            }
            if mods.contains(.option) {
                flags.insert(.maskAlternate)
                modifierKeyCodes.append(58) // Option (左)
            }
            if mods.contains(.shift) {
                flags.insert(.maskShift)
                modifierKeyCodes.append(56) // Shift (左)
            }
            if mods.contains(.command) {
                flags.insert(.maskCommand)
                modifierKeyCodes.append(55) // Command (左)
            }
        }
        
        // 1. 修飾キーのKeyDownイベントを送信
        for modKeyCode in modifierKeyCodes {
            if let modKeyDown = CGEvent(keyboardEventSource: nil, virtualKey: modKeyCode, keyDown: true) {
                modKeyDown.post(tap: .cghidEventTap)
            }
        }
        
        // 2. メインキーのKeyDownイベント
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            // 失敗した場合は修飾キーをリリース
            releaseModifierKeys(modifierKeyCodes)
            return
        }
        keyDown.flags = flags
        keyDown.post(tap: .cghidEventTap)
        
        // 3. メインキーのKeyUpイベント（少し遅延）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                keyUp.flags = flags
                keyUp.post(tap: .cghidEventTap)
            }
            
            // 4. 修飾キーのKeyUpイベントを送信（メインキーの後にリリース）
            self.releaseModifierKeys(modifierKeyCodes)
        }
    }
    
    /// 修飾キーをリリース
    private func releaseModifierKeys(_ modifierKeyCodes: [CGKeyCode]) {
        for modKeyCode in modifierKeyCodes {
            if let modKeyUp = CGEvent(keyboardEventSource: nil, virtualKey: modKeyCode, keyDown: false) {
                modKeyUp.post(tap: .cghidEventTap)
            }
        }
    }
    
    private func stopMonitoringAllButtons() {
        guard let gamepad = controller?.extendedGamepad else { return }
        // 通常の監視に戻す（または無効化）
        gamepad.valueChangedHandler = nil
    }
    
    private func detectButton(from gamepad: GCExtendedGamepad, element: GCControllerElement) {
        var detectedButton: DetectedButton?
        
        // アクションボタン
        if element == gamepad.buttonA, gamepad.buttonA.isPressed {
            detectedButton = DetectedButton(
                id: "button_A",
                displayName: "A",
                buttonType: .button
            )
        } else if element == gamepad.buttonB, gamepad.buttonB.isPressed {
            detectedButton = DetectedButton(
                id: "button_B",
                displayName: "B",
                buttonType: .button
            )
        } else if element == gamepad.buttonX, gamepad.buttonX.isPressed {
            detectedButton = DetectedButton(
                id: "button_X",
                displayName: "X",
                buttonType: .button
            )
        } else if element == gamepad.buttonY, gamepad.buttonY.isPressed {
            detectedButton = DetectedButton(
                id: "button_Y",
                displayName: "Y",
                buttonType: .button
            )
        }
        // バンパー/トリガー
        else if element == gamepad.leftShoulder, gamepad.leftShoulder.isPressed {
            detectedButton = DetectedButton(
                id: "leftShoulder",
                displayName: "LB",
                buttonType: .shoulder
            )
        } else if element == gamepad.rightShoulder, gamepad.rightShoulder.isPressed {
            detectedButton = DetectedButton(
                id: "rightShoulder",
                displayName: "RB",
                buttonType: .shoulder
            )
        } else if element == gamepad.leftTrigger, gamepad.leftTrigger.isPressed {
            detectedButton = DetectedButton(
                id: "leftTrigger",
                displayName: "LT",
                buttonType: .shoulder
            )
        } else if element == gamepad.rightTrigger, gamepad.rightTrigger.isPressed {
            detectedButton = DetectedButton(
                id: "rightTrigger",
                displayName: "RT",
                buttonType: .shoulder
            )
        }
        // スティックボタン
        else if let leftStickButton = gamepad.leftThumbstickButton, element == leftStickButton, leftStickButton.isPressed {
            detectedButton = DetectedButton(
                id: "leftThumbstickButton",
                displayName: "L3",
                buttonType: .stick
            )
        } else if let rightStickButton = gamepad.rightThumbstickButton, element == rightStickButton, rightStickButton.isPressed {
            detectedButton = DetectedButton(
                id: "rightThumbstickButton",
                displayName: "R3",
                buttonType: .stick
            )
        }
        // D-Pad
        else if element == gamepad.dpad {
            if gamepad.dpad.up.isPressed {
                detectedButton = DetectedButton(
                    id: "dpad_up",
                    displayName: "↑",
                    buttonType: .dpad
                )
            } else if gamepad.dpad.down.isPressed {
                detectedButton = DetectedButton(
                    id: "dpad_down",
                    displayName: "↓",
                    buttonType: .dpad
                )
            } else if gamepad.dpad.left.isPressed {
                detectedButton = DetectedButton(
                    id: "dpad_left",
                    displayName: "←",
                    buttonType: .dpad
                )
            } else if gamepad.dpad.right.isPressed {
                detectedButton = DetectedButton(
                    id: "dpad_right",
                    displayName: "→",
                    buttonType: .dpad
                )
            }
        }
        // メニューボタン（3つすべて別々のボタン）
        else if element == gamepad.buttonMenu, gamepad.buttonMenu.isPressed {
            detectedButton = DetectedButton(
                id: "buttonMenu",
                displayName: "+",
                buttonType: .menu
            )
        } else if let optionsButton = gamepad.buttonOptions, element == optionsButton, optionsButton.isPressed {
            detectedButton = DetectedButton(
                id: "buttonOptions",
                displayName: "-",
                buttonType: .menu
            )
        }
        // Homeボタン（完全に別のボタン）
        else if let homeButton = gamepad.buttonHome, element == homeButton, homeButton.isPressed {
            detectedButton = DetectedButton(
                id: "buttonHome",
                displayName: "🏠 Home",
                buttonType: .menu
            )
        }
        
        // ボタンが検出されたら通知
        if let button = detectedButton {
            DispatchQueue.main.async {
                self.lastDetectedButton = button
                self.detectionMessage = "検出: \(button.displayName)"
            }
        }
    }
    
    // MARK: - Button Management
    
    /// ボタンを登録
    func registerButton(_ button: DetectedButton) {
        // 既に登録されていないかチェック
        if !registeredButtons.contains(where: { $0.id == button.id }) {
            registeredButtons.append(button)
            saveButtons()
        }
    }
    
    /// ボタンの名前を変更
    func updateButtonName(id: String, newName: String) {
        if let index = registeredButtons.firstIndex(where: { $0.id == id }) {
            registeredButtons[index].displayName = newName
            saveButtons()
        }
    }
    
    /// ボタンを削除（デフォルトボタンは削除不可）
    func removeButton(id: String) {
        // デフォルトボタンかチェック
        let isDefaultButton = Self.defaultProControllerButtons.contains { $0.id == id }
        
        if isDefaultButton {
            return
        }
        
        registeredButtons.removeAll { $0.id == id }
        saveButtons()
    }
    
    /// カスタムボタンのみクリア（デフォルトボタンは保持）
    func clearCustomButtons() {
        let defaultButtonIds = Set(Self.defaultProControllerButtons.map { $0.id })
        registeredButtons.removeAll { !defaultButtonIds.contains($0.id) }
        saveButtons()
    }
    
    /// すべてのボタンをクリア（デフォルトボタンを含む）
    func clearAllButtons() {
        registeredButtons.removeAll()
        saveButtons()
    }
    
    /// デフォルトボタンかどうかを判定
    func isDefaultButton(_ buttonId: String) -> Bool {
        return Self.defaultProControllerButtons.contains { $0.id == buttonId }
    }
    
    // MARK: - Persistence
    
    private func saveButtons() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(registeredButtons) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadButtons() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([DetectedButton].self, from: data) {
            registeredButtons = decoded
        }
    }
    
    // MARK: - Shortcut Management
    
    /// 複数のショートカットを一括更新（同期用）
    func updateAllShortcuts(configs: [(buttonId: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags?)]) {
        var newShortcuts: [DynamicShortcutBinding] = []
        
        for config in configs {
            let shortcut = DynamicShortcutBinding(
                buttonId: config.buttonId,
                keyCode: config.keyCode,
                modifiers: config.modifiers,
                description: nil
            )
            newShortcuts.append(shortcut)
        }
        
        self.shortcuts = newShortcuts
        self.saveShortcuts()
    }
    
    /// ショートカットを登録
    func registerShortcut(buttonId: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags?, description: String? = nil) {
        // 既存のショートカットを削除
        shortcuts.removeAll { $0.buttonId == buttonId }
        
        // 新しいショートカットを追加
        let shortcut = DynamicShortcutBinding(
            buttonId: buttonId,
            keyCode: keyCode,
            modifiers: modifiers,
            description: description
        )
        shortcuts.append(shortcut)
        saveShortcuts()
    }
    
    /// ショートカットを削除
    func removeShortcut(buttonId: String) {
        shortcuts.removeAll { $0.buttonId == buttonId }
        saveShortcuts()
    }
    
    /// 特定のボタンのショートカットを取得
    func shortcut(for buttonId: String) -> DynamicShortcutBinding? {
        return shortcuts.first { $0.buttonId == buttonId }
    }
    
    /// すべてのショートカットをクリア
    func clearAllShortcuts() {
        shortcuts.removeAll()
        saveShortcuts()
    }
    
    private func saveShortcuts() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: shortcutsStorageKey)
        }
    }
    
    private func loadShortcuts() {
        guard let data = UserDefaults.standard.data(forKey: shortcutsStorageKey) else {
            return
        }
        
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([DynamicShortcutBinding].self, from: data) {
            shortcuts = decoded
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

