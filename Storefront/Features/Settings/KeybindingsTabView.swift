import SwiftUI
import Carbon.HIToolbox

/// Legend of every keyboard shortcut the panel responds to. Bright chips are editable;
/// dimmed chips are fixed.
struct KeybindingsTabView: View {
    @Environment(AppState.self) private var appState
    @State private var globalHotkeyError: String?

    private enum EditableID {
        case globalHotkey
        case openAdmin
        case openOnlineStore
        case focusSearch
        case toggleLinkSearch
        case openCreateLink
    }

    private struct Shortcut {
        let combos: [KeyCombo]
        let description: String
        /// Shown between each pair of combos (e.g. "-" for "⌘1 - ⌘9") — `nil` just uses
        /// plain spacing, for rows like "Move between cards" where either key applies.
        var separator: String? = nil
        var editable: EditableID? = nil
        /// Freeform badge labels when the chord isn't a pure `KeyCombo` (e.g. "⌘-click").
        var customBadges: [String] = []
        /// When set, conflict checks treat every ⌘N in the range as claimed (the UI may
        /// only show the endpoints, e.g. "⌘1 - ⌘9").
        var commandDigitRange: ClosedRange<Int>? = nil
    }

    private struct Group {
        let title: String
        let shortcuts: [Shortcut]
    }

    private var groups: [Group] {
        [
            Group(title: "Global", shortcuts: [
                Shortcut(
                    combos: [appState.settings.globalHotkey],
                    description: "Open or close the panel",
                    editable: .globalHotkey
                ),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_ANSI_Q), modifierFlags: UInt32(cmdKey))], description: "Quit Storefront"),
            ]),
            Group(title: "Store list", shortcuts: [
                Shortcut(
                    combos: [appState.settings.focusSearchHotkey],
                    description: "Focus the store search field",
                    editable: .focusSearch
                ),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_UpArrow), modifierFlags: 0), KeyCombo(keyCode: UInt32(kVK_DownArrow), modifierFlags: 0)], description: "Move through the store list"),
                Shortcut(
                    combos: [
                        KeyCombo(keyCode: UInt32(kVK_ANSI_1), modifierFlags: UInt32(cmdKey)),
                        KeyCombo(keyCode: UInt32(kVK_ANSI_9), modifierFlags: UInt32(cmdKey)),
                    ],
                    description: "Jump to a specific store",
                    separator: "-",
                    commandDigitRange: 1...9
                ),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_RightArrow), modifierFlags: 0)], description: "Enter the section-card grid"),
                Shortcut(
                    combos: [appState.settings.openAdminHotkey],
                    description: "Open Admin for the selected store",
                    editable: .openAdmin
                ),
                Shortcut(
                    combos: [appState.settings.openOnlineStoreHotkey],
                    description: "Open Online Store for the selected store",
                    editable: .openOnlineStore
                ),
            ]),
            Group(title: "Section grid", shortcuts: [
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_LeftArrow), modifierFlags: 0), KeyCombo(keyCode: UInt32(kVK_RightArrow), modifierFlags: 0)], description: "Move between cards"),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_UpArrow), modifierFlags: 0), KeyCombo(keyCode: UInt32(kVK_DownArrow), modifierFlags: 0)], description: "Move between links in a card"),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_Return), modifierFlags: 0)], description: "Open the focused link"),
                Shortcut(
                    combos: [],
                    description: "Open a link and keep the panel open",
                    customBadges: ["⌘-click"]
                ),
                Shortcut(
                    combos: [appState.settings.toggleLinkSearchHotkey],
                    description: "Toggle search on the focused link",
                    editable: .toggleLinkSearch
                ),
                Shortcut(
                    combos: [appState.settings.openCreateLinkHotkey],
                    description: "Open the focused link's \"New +\"",
                    editable: .openCreateLink
                ),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_Escape), modifierFlags: 0)], description: "Step back, then close the panel"),
            ]),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Click a bright key chip to re-record that shortcut. Dimmed keys are fixed.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)

                ForEach(groups, id: \.title) { group in
                    groupCard(group)
                }

                SettingsDocsFooter()
            }
            .padding(18)
        }
        .settingsTopScrollEdgeBlur()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func groupCard(_ group: Group) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textMeta40)
                .padding(.horizontal, 11)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(group.shortcuts.enumerated()), id: \.offset) { index, shortcut in
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Text(shortcut.description)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            HStack(spacing: 6) {
                                if let editable = shortcut.editable {
                                    editableChip(editable)
                                } else if !shortcut.customBadges.isEmpty {
                                    ForEach(shortcut.customBadges, id: \.self) { label in
                                        textBadge(label)
                                    }
                                } else {
                                    ForEach(Array(shortcut.combos.enumerated()), id: \.offset) { index, combo in
                                        if index > 0, let separator = shortcut.separator {
                                            Text(separator)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Theme.textMeta40)
                                        }
                                        keyBadge(combo)
                                    }
                                }
                            }
                        }

                        if let warning = rowWarning(for: shortcut) {
                            Text(warning)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.errorDot)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)

                    if index < group.shortcuts.count - 1 {
                        Divider().overlay(Theme.hairline).padding(.leading, 11)
                    }
                }
            }
            .background(Theme.settingsCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.borderColor, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func editableChip(_ id: EditableID) -> some View {
        let current = currentCombo(id)
        let defaultCombo = defaultCombo(id)

        Button("Reset") {
            applyEditable(id, defaultCombo)
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(current == defaultCombo ? Color.accentColor.opacity(0.35) : Color.accentColor)
        .disabled(current == defaultCombo)
        .help("Reset to default shortcut")

        HotKeyRecorderView(
            combo: Binding(
                get: { currentCombo(id) },
                set: { applyEditable(id, $0) }
            )
        )
    }

    private func currentCombo(_ id: EditableID) -> KeyCombo {
        switch id {
        case .globalHotkey: appState.settings.globalHotkey
        case .openAdmin: appState.settings.openAdminHotkey
        case .openOnlineStore: appState.settings.openOnlineStoreHotkey
        case .focusSearch: appState.settings.focusSearchHotkey
        case .toggleLinkSearch: appState.settings.toggleLinkSearchHotkey
        case .openCreateLink: appState.settings.openCreateLinkHotkey
        }
    }

    private func defaultCombo(_ id: EditableID) -> KeyCombo {
        switch id {
        case .globalHotkey: .default
        case .openAdmin: .openAdminDefault
        case .openOnlineStore: .openOnlineStoreDefault
        case .focusSearch: .focusSearchDefault
        case .toggleLinkSearch: .toggleLinkSearchDefault
        case .openCreateLink: .openCreateLinkDefault
        }
    }

    private func applyEditable(_ id: EditableID, _ newCombo: KeyCombo) {
        switch id {
        case .globalHotkey:
            if GlobalHotKeyManager.shared.updateCombo(newCombo) {
                appState.settings.globalHotkey = newCombo
                appState.save()
                globalHotkeyError = nil
            } else {
                globalHotkeyError = "Couldn't register that shortcut — try a different combo."
                GlobalHotKeyManager.shared.updateCombo(appState.settings.globalHotkey)
            }
        case .openAdmin:
            appState.settings.openAdminHotkey = newCombo
            appState.save()
        case .openOnlineStore:
            appState.settings.openOnlineStoreHotkey = newCombo
            appState.save()
        case .focusSearch:
            appState.settings.focusSearchHotkey = newCombo
            appState.save()
        case .toggleLinkSearch:
            appState.settings.toggleLinkSearchHotkey = newCombo
            appState.save()
        case .openCreateLink:
            appState.settings.openCreateLinkHotkey = newCombo
            appState.save()
        }
    }

    /// Register failure takes priority; otherwise flag chords claimed by another row.
    private func rowWarning(for shortcut: Shortcut) -> String? {
        if shortcut.editable == .globalHotkey, let globalHotkeyError {
            return globalHotkeyError
        }
        guard let id = shortcut.editable else { return nil }
        return conflictWarning(for: id)
    }

    private func conflictWarning(for id: EditableID) -> String? {
        let mine = currentCombo(id)
        let names = claimedCombos(excluding: id)
            .filter { $0.combo == mine }
            .map(\.description)
        let unique = Array(Set(names)).sorted()
        guard !unique.isEmpty else { return nil }
        switch unique.count {
        case 1:
            return "Conflicts with “\(unique[0])”."
        case 2:
            return "Conflicts with “\(unique[0])” and “\(unique[1])”."
        default:
            let rest = unique.count - 2
            return "Conflicts with “\(unique[0])”, “\(unique[1])”, and \(rest) more."
        }
    }

    /// Every chord the legend claims, for duplicate detection. `excluding` skips that
    /// editable row's own combo so a shortcut doesn't warn about itself.
    private func claimedCombos(excluding: EditableID) -> [(combo: KeyCombo, description: String)] {
        var claims: [(KeyCombo, String)] = []
        for group in groups {
            for shortcut in group.shortcuts {
                if shortcut.editable == excluding { continue }
                if let range = shortcut.commandDigitRange {
                    for digit in range {
                        guard let code = KeyCombo.alphanumericKeyCodes[Character("\(digit)")] else { continue }
                        claims.append((
                            KeyCombo(keyCode: UInt32(code), modifierFlags: UInt32(cmdKey)),
                            shortcut.description
                        ))
                    }
                } else {
                    for combo in shortcut.combos {
                        claims.append((combo, shortcut.description))
                    }
                }
            }
        }
        return claims
    }

    private func keyBadge(_ combo: KeyCombo) -> some View {
        KeyComboView(combo: combo, font: .system(size: 11, weight: .medium), glyphHeight: 12)
            .foregroundStyle(Theme.textMeta40)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .frame(minHeight: 22)
            .background(Color.adaptive(light: .black.opacity(0.06), dark: .white.opacity(0.06)))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.borderColor.opacity(0.7), lineWidth: 1))
    }

    private func textBadge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textMeta40)
            .frame(height: 12)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .frame(minHeight: 22)
            .background(Color.adaptive(light: .black.opacity(0.06), dark: .white.opacity(0.06)))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.borderColor.opacity(0.7), lineWidth: 1))
    }
}
