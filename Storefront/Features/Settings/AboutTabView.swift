import SwiftUI
import AppKit

struct AboutTabView: View {
    private static let nuotsuURL = URL(string: "https://nuotsu.dev")!
    private static let repoURL = URL(string: "https://github.com/nuotsu/storefront-macos-menubar")!

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                // Reads the actual configured `AppIcon` asset directly, rather than a
                // duplicated image, so this preview can't drift out of sync with it.
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                Spacer()
            }
            .padding(.bottom, 14)

            Form {
                LabeledContent("App name") {
                    Text("Storefront")
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 4)

                LabeledContent("Description") {
                    Text("Jump into any Shopify store's admin panel in seconds.")
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 4)

                LabeledContent("Version") {
                    Text(Self.appVersionString)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 4)

                LabeledContent("Repository") {
                    Link("GitHub", destination: Self.repoURL)
                }
                .padding(.vertical, 4)

                LabeledContent("Developed by") {
                    Link("nuotsu", destination: Self.nuotsuURL)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private static var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
