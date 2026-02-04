
import SwiftUI

struct AppInfoView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ArKeytect"
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    
    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 20) {

            Image("appicon")
                .resizable()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            Text(appName)
                .font(.system(size: 28, weight: .bold))

            Text(versionString)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Text("本アプリはオープンソースとなっております")
                Text("Github・Twitterアカウントは下記のリンクから")
            }
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
            .padding(.horizontal, 30)

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://github.com/yudo417/ArKeytect")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 16))
                        Text("Source")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.1, green: 0.1, blue: 0.25), Color(red: 0.10, green: 0.15, blue: 0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                
                // Xアカウントリンク
                Link(destination: URL(string: "https://x.com/yudouhu_Cke")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Contact")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.1, green: 0.3, blue: 0.95), Color(red: 0.05, green: 0.2, blue: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(8)
                    .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            Text("© \(currentYear == "2026" ? "2026" : "2016-\(currentYear)") yudo417 All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 20)
        }
        .frame(width: 800, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    AppInfoView()
}


