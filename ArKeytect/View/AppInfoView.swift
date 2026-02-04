import SwiftUI

struct AppInfoView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ProController for Mac"
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "バージョン \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text(appName)
                .font(.title)
                .fontWeight(.semibold)

            Text(versionString)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            VStack(spacing: 8) {
                Text("Nintendo Switch Proコントローラーを使って、")
                Text("Macの操作やショートカットを快適に行うためのツールです。")
            }
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 260)
    }
}

