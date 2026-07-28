import SwiftUI

struct AccountsTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var expandedStoreID: Store.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Store tokens are used to unlock live data (recent products, themes, orders) for the Enriched sections. Create a Custom App in each store's Shopify Admin (Settings → Apps → Develop apps), grant read_products, read_themes, read_orders, then paste the Admin API access token below.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(appState.stores) { store in
                        AccountRow(
                            store: store,
                            isExpanded: expandedStoreID == store.id,
                            onToggleExpand: {
                                expandedStoreID = expandedStoreID == store.id ? nil : store.id
                            }
                        )
                        if store.id != appState.stores.last?.id {
                            Divider().overlay(Theme.divider)
                        }
                    }
                }
            }
            .background(Theme.settingsCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.borderColor, lineWidth: 1))
        }
        .padding(18)
    }
}

private struct AccountRow: View {
    @EnvironmentObject var appState: AppState
    let store: Store
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @State private var tokenText = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(store.color)
                    .frame(width: 7, height: 7)
                Text(store.displayName)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                statusLabel
                Button(store.hasToken ? "Manage" : "Connect…") {
                    onToggleExpand()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .contentShape(Rectangle())

            if isExpanded {
                expandedContent
                    .padding(.horizontal, 11)
                    .padding(.bottom, 11)
            }
        }
    }

    private var statusLabel: some View {
        Group {
            switch store.connectionStatus {
            case .connected:
                Text("Connected").foregroundStyle(Theme.accent)
            case .tokenInvalid:
                Text("Token revoked").foregroundStyle(Theme.errorDot)
            case .staticOnly, .connecting:
                Text("Not connected").foregroundStyle(Theme.textSecondary)
            }
        }
        .font(.system(size: 11))
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.hasToken {
                Text("A token is saved in Keychain for this store.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    Button("Disconnect") {
                        appState.disconnectStore(store)
                        onToggleExpand()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.errorDot)
                }
            } else {
                SecureField("shpat_••••••••••••••••", text: $tokenText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.errorDot)
                }
                HStack(spacing: 8) {
                    Button(isValidating ? "Checking…" : "Save & Connect") {
                        connect()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tokenText.isEmpty || isValidating)
                    Button("Cancel") { onToggleExpand() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.top, 2)
    }

    private func connect() {
        errorMessage = nil
        isValidating = true
        let token = tokenText
        Task {
            do {
                try await appState.connectStore(store, token: token)
                isValidating = false
                tokenText = ""
                onToggleExpand()
            } catch {
                isValidating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
