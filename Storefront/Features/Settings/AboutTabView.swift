import SwiftUI
import AppKit

struct AboutTabView: View {
    private static let nuotsuURL = URL(string: "https://nuotsu.dev")!
    private static let repoURL = URL(string: "https://github.com/nuotsu/storefront-macos-menubar")!
    private static let siteURL = URL(string: "https://storefront.nuotsu.dev")!
    private static let docsURL = URL(string: "https://storefront.nuotsu.dev/docs")!
    private static let feedbackURL = URL(string: "https://storefront.nuotsu.dev/contact?source=settings-about")!

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    // Live Dock icon (Icon Composer Auto, or Light/Dark override).
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    Spacer()
                }
                .padding(.bottom, 14)

                VStack(spacing: 6) {
                    Text("Storefront")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Jump into any Shopify store's admin panel in seconds.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)

                Form {
                    LabeledContent("Version") {
                        Text(Self.appVersionString)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 0)

                    LabeledContent("Repository") {
                        Link("GitHub", destination: Self.repoURL)
                    }
                    .padding(.vertical, 0)

                    LabeledContent("Website") {
                        HStack(spacing: 6) {
                            Link("Homepage", destination: Self.siteURL)
                            Text("·")
                                .foregroundStyle(Theme.textMeta40)
                            Link("Docs", destination: Self.docsURL)
                        }
                    }
                    .padding(.vertical, 0)

                    LabeledContent("Developed by") {
                        Link("nuotsu", destination: Self.nuotsuURL)
                    }
                    .padding(.vertical, 0)
                }

                HStack(spacing: 6) {
                    Button {
                        AppDelegate.shared?.checkForUpdates(nil)
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        NSWorkspace.shared.open(Self.feedbackURL)
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .settingsTopScrollEdgeBlur()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private static var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
