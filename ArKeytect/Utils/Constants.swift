
import Foundation

enum ControlConstants {

    // MARK: - General

    /// スティックのあそび部分（この値未満の入力は無視）
    static let stickDeadzone: Float = 0.1

    /// 入力更新のタイマー間隔（秒）。例: 1/200 = 200Hz
    static let inputUpdateInterval: TimeInterval = 1.0 / 200.0

    // MARK: - Left Stick (カーソル移動)

    /// 左スティック水平方向（X軸）に掛ける係数
    static let leftStickCursorMultiplierX: Float = 0.6
    /// 左スティック垂直方向（Y軸）に掛ける係数
    static let leftStickCursorMultiplierY: Float = 0.6

    // MARK: - Right Stick (スクロール)

    /// 右スティック水平方向（X軸）に掛ける係数
    static let rightStickScrollMultiplierX: Float = 1.0
    /// 右スティック垂直方向（Y軸）に掛ける係数
    static let rightStickScrollMultiplierY: Float = 1.0

    // MARK: - 感度のデフォルト・範囲

    /// 感度のデフォルト値（プロファイル未選択時やレイヤー初期値）
    static let defaultSensitivity: Double = 10.0

    /// 感度の初期値（新規レイヤー・UIスライダー初期値・おすすめ値）
    static let defaultSensitivityForProfile: Double = 30.0

    /// 感度スライダーの最小値
    static let sensitivitySliderMin: Double = 1.0

    /// 感度スライダーの最大値
    static let sensitivitySliderMax: Double = 100.0

    /// 感度スライダーのステップ
    static let sensitivitySliderStep: Double = 1.0
}
