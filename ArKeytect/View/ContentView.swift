//
//  ThreeColumnContentView.swift
//  ProControlerForMac
//
//  3カラム構成のメインView（NavigationSplitView）
//

import SwiftUI
import GameController
import AppKit

struct ContentView: View {
    @EnvironmentObject var controllerMonitor: ControllerMonitor
    @EnvironmentObject var buttonDetector: ButtonDetector
    @EnvironmentObject var profileViewModel: ControllerProfileViewModel
    
    // ナビゲーション状態
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var hasInitializedButtons = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 第1カラム: サイドバー（コントローラーとプロファイル選択）
            SidebarView(
                profileViewModel: profileViewModel
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } content: {
            // 第2カラム: コンテンツ（ボタン一覧）
            ContentListView(
                profileViewModel: profileViewModel,
                buttonDetector: buttonDetector
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 450)
        } detail: {
            // 第3カラム: 詳細設定（ボタン詳細）
            DetailView(
                profileViewModel: profileViewModel,
                buttonDetector: buttonDetector
            )
        }
        .onAppear {
            // ControllerMonitorにProfileViewModelへの参照を設定（感度設定を使用するため）
            // この設定はAppDelegateでも行われているが、念のためここでも設定
            controllerMonitor.profileViewModel = profileViewModel
            
            // ProfileViewModelにButtonDetectorへの参照を設定（念のため）
            profileViewModel.buttonDetector = buttonDetector
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                if !hasInitializedButtons {
                    initializeButtonsFromDetector()
                    hasInitializedButtons = true
                }
                // ショートカット更新はProfileViewModel内で自動的に行われる
                profileViewModel.updateShortcuts()
            }
        }
    }
    
    private func initializeButtonsFromDetector() {
        guard let controllerId = profileViewModel.selectedControllerId,
              let profileId = profileViewModel.selectedProfileId else {
            return
        }
        
        let existingButtonIds = Set(profileViewModel.selectedProfile?.buttonConfigs.compactMap { $0.detectedButtonId } ?? [])
        
        // ButtonDetectorに登録されているボタンで、まだプロファイルに追加されていないものを追加
        for detectedButton in buttonDetector.registeredButtons {
            if !existingButtonIds.contains(detectedButton.id) {
                profileViewModel.addButtonConfig(
                    to: controllerId,
                    profileId: profileId,
                    name: detectedButton.displayName,
                    detectedButtonId: detectedButton.id
                )
            }
        }
    }
}
#Preview {
    ContentView()
        .environmentObject(ControllerMonitor())
        .environmentObject(ButtonDetector())
        .environmentObject(ControllerProfileViewModel())
        .frame(minWidth: 1000, minHeight: 700)
}

