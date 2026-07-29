import SwiftUI
import Carbon.HIToolbox

/// A read-only legend of every keyboard shortcut the panel responds to. Static content —
/// the global hotkey row is the only dynamic one (mirrors whatever's set in General).
struct ShortcutsTabView: View {
    @EnvironmentObject var appState: AppState

    private struct Shortcut {
        let combos: [KeyCombo]
        let description: String
        /// Shown between each pair of combos (e.g. "-" for "⌘1 - ⌘9") — `nil` just uses
        /// plain spacing, for rows like "Move between cards" where either key applies.
        var separator: String? = nil
    }

    private struct Group {
        let title: String
        let shortcuts: [Shortcut]
    }

    private var groups: [Group] {
        [
            Group(title: "GLOBAL", shortcuts: [
                Shortcut(combos: [appState.settings.globalHotkey], description: "Open or close the panel"),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_ANSI_Q), modifierFlags: UInt32(cmdKey))], description: "Quit Storefront"),
            ]),
            Group(title: "STORE LIST", shortcuts: [
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_UpArrow), modifierFlags: 0), KeyCombo(keyCode: UInt32(kVK_DownArrow), modifierFlags: 0)], description: "Move through the store list"),
                Shortcut(
                    combos: [
                        KeyCombo(keyCode: UInt32(kVK_ANSI_1), modifierFlags: UInt32(cmdKey)),
                        KeyCombo(keyCode: UInt32(kVK_ANSI_9), modifierFlags: UInt32(cmdKey)),
                    ],
                    description: "Jump to a specific store",
                    separator: "-"
                ),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_RightArrow), modifierFlags: 0)], description: "Enter the section-card grid"),
            ]),
            Group(title: "SECTION GRID", shortcuts: [
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_LeftArrow), modifierFlags: 0), KeyCombo(keyCode: UInt32(kVK_RightArrow), modifierFlags: 0)], description: "Move between cards"),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_UpArrow), modifierFlags: 0), KeyCombo(keyCode: UInt32(kVK_DownArrow), modifierFlags: 0)], description: "Move between links in a card"),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_Return), modifierFlags: 0)], description: "Open the focused link"),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_ANSI_S), modifierFlags: UInt32(controlKey))], description: "Toggle search on the focused link"),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifierFlags: UInt32(controlKey))], description: "Open the focused link's \"New +\""),
                Shortcut(combos: [KeyCombo(keyCode: UInt32(kVK_Escape), modifierFlags: 0)], description: "Step back, then close the panel"),
            ]),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groups, id: \.title) { group in
                    groupCard(group)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func groupCard(_ group: Group) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.title)
                .font(.mono(10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMeta40)
                .padding(.horizontal, 11)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(group.shortcuts.enumerated()), id: \.offset) { index, shortcut in
                    HStack {
                        Text(shortcut.description)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        HStack(spacing: 6) {
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

    private func keyBadge(_ combo: KeyCombo) -> some View {
        KeyComboView(combo: combo, font: .system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.railBackground)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.borderColor, lineWidth: 1))
    }
}
