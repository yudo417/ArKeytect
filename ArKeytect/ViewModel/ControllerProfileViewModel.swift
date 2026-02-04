
import Foundation
import SwiftUI
import Combine
import GameController

// MARK: - Detail Selection

/// DetailView で表示する内容の種類
enum DetailSelection: Equatable {
    case button(UUID)    // ButtonConfig.id
    case leftStick
    case rightStick
    case none
}

class ControllerProfileViewModel: ObservableObject {
    /// すべてのコントローラー
    @Published var controllers: [Controller] = []
    /// 選択中のコントローラーID
    @Published var selectedControllerId: UUID?
    /// 選択中のプロファイルID
    @Published var selectedProfileId: UUID?
    /// 選択中のボタン設定ID
    @Published var selectedButtonConfigId: UUID?
    /// 選択中のレイヤーインデックス
    @Published var selectedLayerIndex: Int = 0
    /// DetailView の表示内容
    @Published var detailSelection: DetailSelection = .none

    private let storageKey = "ControllerProfiles"
    private var cancellables = Set<AnyCancellable>()
    
    // ZR/ZLの状態追跡（同時押し判定用）
    private var isZRPressed: Bool = false
    private var isZLPressed: Bool = false
    /// 左/右クリックボタンが押しっぱなしか（ドラッグ時にスティックで leftMouseDragged を送るため）
    private(set) var isLeftClickButtonHeld: Bool = false
    private(set) var isRightClickButtonHeld: Bool = false
    /// 選択中のコントローラー
    var selectedController: Controller? {
        guard let id = selectedControllerId else { return nil }
        return controllers.first { $0.id == id }
    }
    /// 選択中のプロファイル
    var selectedProfile: Profile? {
        guard let controller = selectedController,
              let profileId = selectedProfileId else { return nil }
        return controller.profiles.first { $0.id == profileId }
    }
    /// 選択中のボタン設定
    var selectedButtonConfig: ButtonConfig? {
        guard let profile = selectedProfile,
              let buttonId = selectedButtonConfigId,
              selectedLayerIndex < profile.layers.count else { return nil }
        return profile.layers[selectedLayerIndex].buttonConfigs.first { $0.id == buttonId }
    }
    
    // MARK: - Initialization
    
    init() {
        $controllers
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            self?.loadData()
            self?.setupDefaultData()
            self?.setupControllerMonitoring()
        }
    }
    
    // MARK: - Controller Management
    
    /// コントローラーを追加
    func addController(name: String) -> Controller {
        let controller = Controller(name: name, isConnected: false)
        controllers.append(controller)
        return controller
    }
    
    /// コントローラーを削除
    func removeController(id: UUID) {
        controllers.removeAll { $0.id == id }
        if selectedControllerId == id {
            selectedControllerId = nil
            selectedProfileId = nil
            selectedButtonConfigId = nil
        }
    }
    
    /// コントローラーの接続状態を更新
    func updateControllerConnection(id: UUID, isConnected: Bool) {
        if let index = controllers.firstIndex(where: { $0.id == id }) {
            controllers[index].isConnected = isConnected
        }
    }

    func renameController(id: UUID, name: String) {
        
    }

    // MARK: - Profile Management
    
    /// プロファイルを追加
    func addProfile(to controllerId: UUID, name: String, icon: String = "folder.fill") -> Profile? {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }) else {
            return nil
        }
        
        // デフォルトボタンの設定からButtonConfigを生成
        let defaultButtonConfigs = ButtonDetector.defaultProControllerButtons.map { detectedButton in
            ButtonConfig(
                name: detectedButton.displayName,
                detectedButtonId: detectedButton.id
            )
        }
        
        let defaultLayer = Layer(name: "Default", buttonConfigs: defaultButtonConfigs)
        let profile = Profile(name: name, icon: icon, layers: [defaultLayer])
        
        controllers[controllerIndex].profiles.append(profile)
        return profile
    }

    /// 選択したプロフィールを削除
    func removeProfile(controllerId: UUID, profileId: UUID) {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }) else {
            return
        }
        
        controllers[controllerIndex].profiles.removeAll { $0.id == profileId }
        
        if selectedProfileId == profileId {
            selectedProfileId = nil
            selectedButtonConfigId = nil
        }
    }
    
    /// プロファイルを更新
    func updateProfile(controllerId: UUID, profileId: UUID, name: String? = nil, icon: String? = nil) {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }),
              let profileIndex = controllers[controllerIndex].profiles.firstIndex(where: { $0.id == profileId }) else {
            return
        }
        
        if let name = name {
            controllers[controllerIndex].profiles[profileIndex].name = name
        }
        if let icon = icon {
            controllers[controllerIndex].profiles[profileIndex].icon = icon
        }
    }
    
    /// プロファイルの同時押しレイヤーを設定
    func setDualTriggerLayer(controllerId: UUID, profileId: UUID, layerId: UUID?) {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }),
              let profileIndex = controllers[controllerIndex].profiles.firstIndex(where: { $0.id == profileId }) else {
            return
        }
        
        controllers[controllerIndex].profiles[profileIndex].dualTriggerLayerId = layerId
    }
    
    // MARK: - Layer Management
    
    /// レイヤーを追加
    func addLayer(to controllerId: UUID, profileId: UUID, name: String) -> Layer? {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }),
              let profileIndex = controllers[controllerIndex].profiles.firstIndex(where: { $0.id == profileId }) else {
            return nil
        }
        
        // デフォルトのボタン設定をコピー（空だと不便なので）
        let defaultButtonConfigs = ButtonDetector.defaultProControllerButtons.map { detectedButton in
            ButtonConfig(
                name: detectedButton.displayName,
                detectedButtonId: detectedButton.id
            )
        }
        
        let layer = Layer(name: name, buttonConfigs: defaultButtonConfigs)
        controllers[controllerIndex].profiles[profileIndex].layers.append(layer)
        return layer
    }
    
    /// レイヤーを削除
    func removeLayer(controllerId: UUID, profileId: UUID, layerIndex: Int) {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }),
              let profileIndex = controllers[controllerIndex].profiles.firstIndex(where: { $0.id == profileId }) else {
            return
        }
        
        // Defaultレイヤー（インデックス0）は削除禁止
        if layerIndex > 0 && layerIndex < controllers[controllerIndex].profiles[profileIndex].layers.count {
            controllers[controllerIndex].profiles[profileIndex].layers.remove(at: layerIndex)
        }
    }

    // MARK: - ButtonConfig Management
    
    /// ボタン設定を追加 (layerIndex指定対応版)
    func addButtonConfig(to controllerId: UUID, profileId: UUID, layerIndex: Int = 0, name: String, detectedButtonId: String? = nil) -> ButtonConfig? {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }),
              let profileIndex = controllers[controllerIndex].profiles.firstIndex(where: { $0.id == profileId }),
              layerIndex < controllers[controllerIndex].profiles[profileIndex].layers.count else {
            return nil
        }
        
        let buttonConfig = ButtonConfig(name: name, detectedButtonId: detectedButtonId)
        controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].buttonConfigs.append(buttonConfig)
        return buttonConfig
    }
    
    /// ボタン設定を削除 (layerIndex指定対応版)
    func removeButtonConfig(controllerId: UUID, profileId: UUID, layerIndex: Int = 0, buttonConfigId: UUID) {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }),
              let profileIndex = controllers[controllerIndex].profiles.firstIndex(where: { $0.id == profileId }),
              layerIndex < controllers[controllerIndex].profiles[profileIndex].layers.count else {
            return
        }
        
        controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].buttonConfigs.removeAll { $0.id == buttonConfigId }
        
        if selectedButtonConfigId == buttonConfigId {
            selectedButtonConfigId = nil
        }
    }
    
    /// ボタン設定を更新 (layerIndex指定対応版)
    func updateButtonConfig(
        controllerId: UUID,
        profileId: UUID,
        layerIndex: Int = 0,
        buttonConfigId: UUID,
        name: String? = nil,
        actionType: ButtonActionType? = nil,
        keyCode: UInt16? = nil,
        modifierFlags: NSEvent.ModifierFlags? = nil,
        targetLayerId: UUID? = nil,
        shouldUpdateTargetLayerId: Bool = false,
        shouldUpdateModifierFlags: Bool = false
    ) {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }),
              let profileIndex = controllers[controllerIndex].profiles.firstIndex(where: { $0.id == profileId }),
              layerIndex < controllers[controllerIndex].profiles[profileIndex].layers.count,
              let buttonIndex = controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].buttonConfigs.firstIndex(where: { $0.id == buttonConfigId }) else {
            return
        }
        
        var config = controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].buttonConfigs[buttonIndex]
        
        if let name = name { config.name = name }
        if let actionType = actionType { config.actionType = actionType }
        if let keyCode = keyCode {
            config.keyCode = keyCode
            config.assignedKey = KeyCodeConverter.keyCodeToString(keyCode)
        }
        
        // modifierFlagsの更新ロジック（nilクリア対応）
        if shouldUpdateModifierFlags {
            config.modifierFlags = modifierFlags
        } else if let modifierFlags = modifierFlags {
            config.modifierFlags = modifierFlags
        }
        
        // targetLayerIdの更新ロジック（nilクリア対応）
        if shouldUpdateTargetLayerId {
            config.targetLayerId = targetLayerId
        } else if let targetLayerId = targetLayerId {
            config.targetLayerId = targetLayerId
        }
        
        controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].buttonConfigs[buttonIndex] = config
    }
    
    /// ボタン設定をリセット
    func resetButtonConfig(controllerId: UUID, profileId: UUID, layerIndex: Int = 0, buttonConfigId: UUID) {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }),
              let profileIndex = controllers[controllerIndex].profiles.firstIndex(where: { $0.id == profileId }),
              layerIndex < controllers[controllerIndex].profiles[profileIndex].layers.count,
              let buttonIndex = controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].buttonConfigs.firstIndex(where: { $0.id == buttonConfigId }) else {
            return
        }
        
        // 名前とdetectedButtonId以外を初期化
        var config = controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].buttonConfigs[buttonIndex]
        config.actionType = .keyInput
        config.keyCode = nil
        config.assignedKey = nil
        config.modifierFlagsRawValue = nil
        config.targetLayerId = nil
        
        controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].buttonConfigs[buttonIndex] = config
    }
    
    // MARK: - Input Handling
    
    /// ボタン入力イベントを処理（レイヤー切り替え、マウスクリックなど）
    func handleButtonEvent(buttonId: String, isPressed: Bool) {
        guard let profile = selectedProfile else { return }
        
        // ZR/ZLの状態を更新
        if buttonId == "rightTrigger" {
            isZRPressed = isPressed
        } else if buttonId == "leftTrigger" {
            isZLPressed = isPressed
        }
        
        // 0. 同時押しレイヤーの判定（最優先）
        // ZRとZLの両方が押されている場合、プロファイルのdualTriggerLayerIdを参照
        if isZRPressed && isZLPressed {
            if let dualLayerId = profile.dualTriggerLayerId,
               let dualLayer = profile.layers.first(where: { $0.id == dualLayerId }),
               let dualLayerIndex = profile.layers.firstIndex(where: { $0.id == dualLayerId }) {
                DispatchQueue.main.async {
                    self.selectedLayerIndex = dualLayerIndex
                }
                return // 同時押しレイヤーが優先される
            }
        }
        
        // 1. 現在のレイヤーでの設定を確認
        if selectedLayerIndex < profile.layers.count {
            if let config = profile.layers[selectedLayerIndex].buttonConfigs.first(where: { $0.detectedButtonId == buttonId }) {
                switch config.actionType {
                case .layerShift:
                    if isPressed, let targetId = config.targetLayerId {
                        // ターゲットレイヤーへ切り替え
                        if let targetIndex = profile.layers.firstIndex(where: { $0.id == targetId }) {
                            DispatchQueue.main.async {
                                self.selectedLayerIndex = targetIndex
                            }
                        }
                    } else if !isPressed {
                        // ボタンを離したらデフォルト(0)に戻す（ただし同時押し中は除く）
                        if !(isZRPressed && isZLPressed) {
                            DispatchQueue.main.async {
                                self.selectedLayerIndex = 0
                            }
                        }
                    }
                    return
                    
                case .leftClick:
                    executeMouseClick(isPressed: isPressed, isRightClick: false, modifierFlags: config.modifierFlags)
                    return
                    
                case .rightClick:
                    executeMouseClick(isPressed: isPressed, isRightClick: true, modifierFlags: config.modifierFlags)
                    return
                    
                case .keyInput:
                    // キー入力は ButtonDetector で処理されるので、ここでは何もしない
                    break
                }
            }
        }
        
        // 2. 単一トリガーボタンによるレイヤー切り替え（triggerButtonIdを使用）
        // レイヤー0から、triggerButtonIdが一致するレイヤーを探す
        if let baseLayer = profile.layers.first, selectedLayerIndex == 0 {
            // ZRのみが押されている場合
            if isZRPressed && !isZLPressed {
                if let zrLayer = profile.layers.first(where: { $0.triggerButtonId == "rightTrigger" }) {
                    if let zrLayerIndex = profile.layers.firstIndex(where: { $0.id == zrLayer.id }) {
                        DispatchQueue.main.async {
                            self.selectedLayerIndex = zrLayerIndex
                        }
                        return
                    }
                }
            }
            // ZLのみが押されている場合
            else if isZLPressed && !isZRPressed {
                if let zlLayer = profile.layers.first(where: { $0.triggerButtonId == "leftTrigger" }) {
                    if let zlLayerIndex = profile.layers.firstIndex(where: { $0.id == zlLayer.id }) {
                        DispatchQueue.main.async {
                            self.selectedLayerIndex = zlLayerIndex
                        }
                        return
                    }
                }
            }
        }
        
        // 3. 現在レイヤーシフト中(index != 0)で、ボタンが離された場合
        // 同時押しが解除された場合、または単一トリガーが離された場合
        if !isPressed && selectedLayerIndex != 0 {
            // 同時押しが解除された場合
            if buttonId == "rightTrigger" || buttonId == "leftTrigger" {
                if !(isZRPressed && isZLPressed) {
                    // どちらかが離された場合、デフォルトに戻す
                    DispatchQueue.main.async {
                        self.selectedLayerIndex = 0
                    }
                }
            }
            // レイヤー0の設定を確認
            else if let baseConfig = profile.layers.first?.buttonConfigs.first(where: { $0.detectedButtonId == buttonId }) {
                if baseConfig.actionType == .layerShift {
                    DispatchQueue.main.async {
                        self.selectedLayerIndex = 0
                    }
                }
            }
        }
    }
    
    // MARK: - Mouse Click
    
    /// マウスクリックイベントを発行
    private func executeMouseClick(isPressed: Bool, isRightClick: Bool, modifierFlags: NSEvent.ModifierFlags?) {
        guard let event = CGEvent(source: nil) else { return }
        let position = event.location
        
        let mouseButton: CGMouseButton = isRightClick ? .right : .left
        
        // 修飾キーのフラグを設定（ButtonDetectorと同じ方法で変換）
        var flags: CGEventFlags = []
        if let mods = modifierFlags {
            if mods.contains(.control) {
                flags.insert(.maskControl)
            }
            if mods.contains(.option) {
                flags.insert(.maskAlternate)
            }
            if mods.contains(.shift) {
                flags.insert(.maskShift)
            }
            if mods.contains(.command) {
                flags.insert(.maskCommand)
            }
        }
        
        if isPressed {
            if isRightClick {
                isRightClickButtonHeld = true
            } else {
                isLeftClickButtonHeld = true
            }
            let eventType: CGEventType = isRightClick ? .rightMouseDown : .leftMouseDown
            if let downEvent = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: position, mouseButton: mouseButton) {
                downEvent.flags = flags
                downEvent.post(tap: .cghidEventTap)
            }
        } else {
            if isRightClick {
                isRightClickButtonHeld = false
            } else {
                isLeftClickButtonHeld = false
            }
            let eventType: CGEventType = isRightClick ? .rightMouseUp : .leftMouseUp
            if let upEvent = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: position, mouseButton: mouseButton) {
                upEvent.flags = flags
                upEvent.post(tap: .cghidEventTap)
            }
        }
    }
    
    // MARK: - Stick Sensitivity
    
    /// スティック感度を更新
    func updateStickSensitivity(
        controllerId: UUID,
        profileId: UUID,
        layerIndex: Int,
        isLeftStick: Bool,
        sensitivity: Double
    ) {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }),
              let profileIndex = controllers[controllerIndex].profiles.firstIndex(where: { $0.id == profileId }),
              layerIndex < controllers[controllerIndex].profiles[profileIndex].layers.count else {
            return
        }
        
        if isLeftStick {
            controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].leftStickSensitivity = sensitivity
        } else {
            controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].rightStickSensitivity = sensitivity
        }
    }
    
    /// 現在選択中のレイヤーのスティック感度を取得
    func currentStickSensitivity(isLeftStick: Bool) -> Double {
        guard let profile = selectedProfile,
              selectedLayerIndex < profile.layers.count else {
            return 10.0 // デフォルト値
        }
        
        let layer = profile.layers[selectedLayerIndex]
        return isLeftStick ? layer.leftStickSensitivity : layer.rightStickSensitivity
    }
    
    /// 右スティックのスクロール方向設定を更新
    func updateRightStickScrollDirection(
        controllerId: UUID,
        profileId: UUID,
        layerIndex: Int,
        verticalInverted: Bool,
        horizontalInverted: Bool
    ) {
        guard let controllerIndex = controllers.firstIndex(where: { $0.id == controllerId }),
              let profileIndex = controllers[controllerIndex].profiles.firstIndex(where: { $0.id == profileId }),
              layerIndex < controllers[controllerIndex].profiles[profileIndex].layers.count else {
            return
        }
        
        controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].rightStickScrollVerticalInverted = verticalInverted
        controllers[controllerIndex].profiles[profileIndex].layers[layerIndex].rightStickScrollHorizontalInverted = horizontalInverted
    }
    
    /// 現在選択中のレイヤーの右スティックスクロール方向設定を取得
    func currentRightStickScrollDirection() -> (verticalInverted: Bool, horizontalInverted: Bool) {
        guard let profile = selectedProfile,
              selectedLayerIndex < profile.layers.count else {
            return (verticalInverted: false, horizontalInverted: false) // デフォルト値
        }
        
        let layer = profile.layers[selectedLayerIndex]
        return (verticalInverted: layer.rightStickScrollVerticalInverted, horizontalInverted: layer.rightStickScrollHorizontalInverted)
    }
    
    // MARK: - Default Data Setup
    
    private func setupDefaultData() {
        // 既にデータがある場合はスキップ
        if !controllers.isEmpty {
            return
        }
        
        // デフォルトコントローラーを作成
        let defaultController = Controller(
            name: "Pro Controller",
            isConnected: false,
            profiles: [
                Profile(
                    name: "Default",
                    icon: "star.fill",
                    layers: [
                        Layer(name: "Default", buttonConfigs: [])
                    ]
                )
            ]
        )
        
        controllers.append(defaultController)
        selectedControllerId = defaultController.id
        selectedProfileId = defaultController.profiles.first?.id
    }
    
    // MARK: - Controller Monitoring
    
    private func setupControllerMonitoring() {
        // コントローラー接続監視
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.handleControllerConnect(controller)
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.handleControllerDisconnect(controller)
        }
        
        // 既存のコントローラーをチェック
        if let existingController = GCController.controllers().first {
            handleControllerConnect(existingController)
        }
    }
    
    private func handleControllerConnect(_ controller: GCController) {
        let controllerName = controller.vendorName ?? "Unknown Controller"
        
        // 既存のコントローラーを探す
        if let existingIndex = controllers.firstIndex(where: { $0.name == controllerName }) {
            controllers[existingIndex].isConnected = true
            if selectedControllerId == nil {
                selectedControllerId = controllers[existingIndex].id
            }
        } else {
            // 新しいコントローラーを追加
            let newController = Controller(
                name: controllerName,
                isConnected: true,
                profiles: [
                    Profile(
                        name: "Default",
                        icon: "star.fill",
                        layers: [
                            Layer(name: "Default", buttonConfigs: [])
                        ]
                    )
                ]
            )
            controllers.append(newController)
            if selectedControllerId == nil {
                selectedControllerId = newController.id
                selectedProfileId = newController.profiles.first?.id
            }
        }
    }
    
    private func handleControllerDisconnect(_ controller: GCController) {
        let controllerName = controller.vendorName ?? "Unknown Controller"
        
        if let index = controllers.firstIndex(where: { $0.name == controllerName }) {
            controllers[index].isConnected = false
        }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(controllers) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadData() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([Controller].self, from: data) {
            controllers = decoded
            
            // 最初のコントローラーとプロファイルを選択
            if let firstController = controllers.first {
                selectedControllerId = firstController.id
                if let firstProfile = firstController.profiles.first {
                    selectedProfileId = firstProfile.id
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

