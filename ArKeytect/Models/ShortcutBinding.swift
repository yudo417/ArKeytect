//
//  ShortcutBinding.swift
//  ProControlerForMac
//
//  ショートカット設定のモデル
//

import Foundation
import AppKit

/// コントローラーのボタン種類
enum ControllerButton: String, Codable, CaseIterable {
    case buttonA = "A"
    case buttonB = "B"
    case buttonX = "X"
    case buttonY = "Y"
    case leftBumper = "LB"
    case rightBumper = "RB"
    case leftTrigger = "LT"
    case rightTrigger = "RT"
    case leftStickButton = "L3"
    case rightStickButton = "R3"
    case dpadUp = "D-Pad Up"
    case dpadDown = "D-Pad Down"
    case dpadLeft = "D-Pad Left"
    case dpadRight = "D-Pad Right"
    case menu = "Menu"
    case options = "Options"
    
    var displayName: String {
        return rawValue
    }
    
    /// ボタンのカテゴリ
    var category: ButtonCategory {
        switch self {
        case .buttonA, .buttonB, .buttonX, .buttonY:
            return .action
        case .leftBumper, .rightBumper, .leftTrigger, .rightTrigger:
            return .shoulderTrigger
        case .leftStickButton, .rightStickButton:
            return .stick
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight:
            return .dpad
        case .menu, .options:
            return .menu
        }
    }
    
    /// ボタンのアイコン
    var icon: String {
        switch self {
        case .buttonA:
            return "a.circle.fill"
        case .buttonB:
            return "b.circle.fill"
        case .buttonX:
            return "x.circle.fill"
        case .buttonY:
            return "y.circle.fill"
        case .leftBumper:
            return "l1.rectangle.roundedbottom.fill"
        case .rightBumper:
            return "r1.rectangle.roundedbottom.fill"
        case .leftTrigger:
            return "l2.rectangle.roundedtop.fill"
        case .rightTrigger:
            return "r2.rectangle.roundedtop.fill"
        case .leftStickButton:
            return "l.joystick.press.down.fill"
        case .rightStickButton:
            return "r.joystick.press.down.fill"
        case .dpadUp:
            return "dpad.up.filled"
        case .dpadDown:
            return "dpad.down.filled"
        case .dpadLeft:
            return "dpad.left.filled"
        case .dpadRight:
            return "dpad.right.filled"
        case .menu:
            return "line.3.horizontal"
        case .options:
            return "ellipsis"
        }
    }
}

/// ボタンカテゴリ
enum ButtonCategory: String {
    case action = "アクションボタン"
    case shoulderTrigger = "バンパー/トリガー"
    case stick = "スティックボタン"
    case dpad = "D-Pad"
    case menu = "メニュー"
    
    /// カテゴリに属するボタン
    var buttons: [ControllerButton] {
        ControllerButton.allCases.filter { $0.category == self }
    }
}

/// 1つのショートカット設定
struct ShortcutBinding: Codable, Identifiable {
    var id: String { button.rawValue }
    
    /// どのボタンに割り当てるか
    let button: ControllerButton
    
    /// キーコード（例: 40 = K）
    let keyCode: UInt16
    
    /// 修飾キー（オプション）
    let modifiers: UInt?  // NSEvent.ModifierFlags.rawValue
    
    /// 説明（オプション）
    var description: String?
    
    /// 有効/無効
    var isEnabled: Bool = true
    
    init(button: ControllerButton, keyCode: UInt16, modifiers: NSEvent.ModifierFlags? = nil, description: String? = nil) {
        self.button = button
        self.keyCode = keyCode
        self.modifiers = modifiers?.rawValue
        self.description = description
    }
    
    /// NSEvent.ModifierFlagsとして取得
    var modifierFlags: NSEvent.ModifierFlags? {
        guard let rawValue = modifiers else { return nil }
        return NSEvent.ModifierFlags(rawValue: rawValue)
    }
    
    /// 人間が読める形式で表示
    var displayString: String {
        let keyName = KeyCodeConverter.keyCodeToString(keyCode)
        if let mods = modifierFlags {
            let modString = KeyCodeConverter.modifiersToString(mods)
            return modString.isEmpty ? keyName : "\(modString) + \(keyName)"
        }
        return keyName
    }
}

/// 動的に登録されたボタンのショートカット設定
struct DynamicShortcutBinding: Codable, Identifiable {
    var id: String { buttonId }  // DetectedButton.idと一致
    
    /// どのボタンに割り当てるか（DetectedButton.id）
    let buttonId: String
    
    /// キーコード（例: 40 = K）
    let keyCode: UInt16
    
    /// 修飾キー（オプション）
    let modifiers: UInt?  // NSEvent.ModifierFlags.rawValue
    
    /// 説明（オプション）
    var description: String?
    
    /// 有効/無効
    var isEnabled: Bool = true
    
    init(buttonId: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags? = nil, description: String? = nil) {
        self.buttonId = buttonId
        self.keyCode = keyCode
        self.modifiers = modifiers?.rawValue
        self.description = description
    }
    
    /// NSEvent.ModifierFlagsとして取得
    var modifierFlags: NSEvent.ModifierFlags? {
        guard let rawValue = modifiers else { return nil }
        return NSEvent.ModifierFlags(rawValue: rawValue)
    }
    
    /// 人間が読める形式で表示
    var displayString: String {
        let keyName = KeyCodeConverter.keyCodeToString(keyCode)
        if let mods = modifierFlags {
            let modString = KeyCodeConverter.modifiersToString(mods)
            return modString.isEmpty ? keyName : "\(modString) + \(keyName)"
        }
        return keyName
    }
}

/// ショートカット設定の保存・読み込みを管理
class ShortcutStorage {
    private static let storageKey = "ShortcutBindings"
    
    /// すべてのショートカット設定を保存
    static func saveBindings(_ bindings: [ShortcutBinding]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(bindings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    /// すべてのショートカット設定を読み込み
    static func loadBindings() -> [ShortcutBinding] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([ShortcutBinding].self, from: data) {
            return decoded
        }
        
        return []
    }
    
    /// 特定のボタンのショートカットを取得
    static func binding(for button: ControllerButton) -> ShortcutBinding? {
        return loadBindings().first { $0.button == button }
    }
    
    /// 特定のボタンのショートカットを更新
    static func updateBinding(_ binding: ShortcutBinding) {
        var bindings = loadBindings()
        
        // 既存の設定を削除
        bindings.removeAll { $0.button == binding.button }
        
        // 新しい設定を追加
        bindings.append(binding)
        
        saveBindings(bindings)
    }
    
    /// 特定のボタンのショートカットを削除
    static func removeBinding(for button: ControllerButton) {
        var bindings = loadBindings()
        bindings.removeAll { $0.button == button }
        saveBindings(bindings)
    }
    
    /// すべてのショートカットをクリア
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

