import Carbon.HIToolbox
import SwiftUI

/// Short first-run guide for Settings — three steps to get productive.
struct HowToUseTabView: View {
    @EnvironmentObject var appState: AppState

    private struct ShortcutBullet: Identifiable {
        let id: String
        let label: String
        var combos: [KeyCombo] = []
        /// Shown between each pair of combos (e.g. "-" for "⌘1 - ⌘9").
        var separator: String? = nil
        var customBadges: [String] = []
    }

    private struct Step: Identifiable {
        let id: Int
        let title: String
        let body: String
        var bullets: [ShortcutBullet] = []
        let actionTitle: String?
        let actionTab: SettingsTab?
    }

    private var steps: [Step] {
        [
            Step(
                id: 1,
                title: "Add your stores",
                body: "From Settings (⌘,), open Stores and add each shop by its myshopify.com domain. Rename, recolor, hide, reorder, or import a CSV anytime.",
                actionTitle: "Open Stores",
                actionTab: .stores
            ),
            Step(
                id: 2,
                title: "Customize your cards",
                body: "In Sections, choose which admin cards appear in the panel and drag to reorder them. Save presets for different roles or workflows.",
                actionTitle: "Open Sections",
                actionTab: .sections
            ),
            Step(
                id: 3,
                title: "Navigate the panel",
                body: "Open Storefront from the menu bar or your global hotkey. Use the keyboard to move around:",
                bullets: [
                    ShortcutBullet(
                        id: "open",
                        label: "Open or close the panel",
                        combos: [appState.settings.globalHotkey]
                    ),
                    ShortcutBullet(
                        id: "stores",
                        label: "Move through stores",
                        combos: [
                            KeyCombo(keyCode: UInt32(kVK_UpArrow), modifierFlags: 0),
                            KeyCombo(keyCode: UInt32(kVK_DownArrow), modifierFlags: 0),
                        ]
                    ),
                    ShortcutBullet(
                        id: "cards",
                        label: "Move between cards",
                        combos: [
                            KeyCombo(keyCode: UInt32(kVK_LeftArrow), modifierFlags: 0),
                            KeyCombo(keyCode: UInt32(kVK_RightArrow), modifierFlags: 0),
                        ]
                    ),
                    ShortcutBullet(
                        id: "links",
                        label: "Move between links",
                        combos: [
                            KeyCombo(keyCode: UInt32(kVK_UpArrow), modifierFlags: 0),
                            KeyCombo(keyCode: UInt32(kVK_DownArrow), modifierFlags: 0),
                        ]
                    ),
                    ShortcutBullet(
                        id: "openLink",
                        label: "Open the focused link",
                        combos: [KeyCombo(keyCode: UInt32(kVK_Return), modifierFlags: 0)]
                    ),
                    ShortcutBullet(
                        id: "jump",
                        label: "Jump to a store",
                        combos: [
                            KeyCombo(keyCode: UInt32(kVK_ANSI_1), modifierFlags: UInt32(cmdKey)),
                            KeyCombo(keyCode: UInt32(kVK_ANSI_9), modifierFlags: UInt32(cmdKey)),
                        ],
                        separator: "-"
                    ),
                ],
                actionTitle: "Open Keybindings",
                actionTab: .keybindings
            ),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Get from an empty install to jumping into Shopify admin in three steps.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)

                ForEach(steps) { step in
                    stepCard(step)
                }
            }
            .padding(18)
        }
        .settingsTopScrollEdgeBlur()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func stepCard(_ step: Step) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step.id)")
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.textMeta40)
                .frame(width: 24, alignment: .trailing)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 0) {
                Text(step.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 11)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                Text(step.body)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 11)
                    .padding(.bottom, step.bullets.isEmpty ? (step.actionTab == nil ? 12 : 8) : 8)

                if !step.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(step.bullets) { bullet in
                            HStack(alignment: .center, spacing: 8) {
                                Text("•")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.textSecondary)
                                Text(bullet.label)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer(minLength: 8)
                                HStack(spacing: 6) {
                                    if !bullet.customBadges.isEmpty {
                                        ForEach(bullet.customBadges, id: \.self) { label in
                                            textBadge(label)
                                        }
                                    } else {
                                        ForEach(Array(bullet.combos.enumerated()), id: \.offset) { index, combo in
                                            if index > 0, let separator = bullet.separator {
                                                Text(separator)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(Theme.textMeta40)
                                            }
                                            keyBadge(combo)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.bottom, step.actionTab == nil ? 12 : 8)
                }

                if let actionTitle = step.actionTitle, let actionTab = step.actionTab {
                    Button(actionTitle) {
                        appState.selectedSettingsTab = actionTab
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 11)
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.settingsCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.borderColor, lineWidth: 1)
            )
        }
    }

    private func keyBadge(_ combo: KeyCombo) -> some View {
        KeyComboView(combo: combo, font: .system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textMeta40)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.adaptive(light: .white, dark: .white.opacity(0.12)))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.borderColor.opacity(0.7), lineWidth: 1))
    }

    private func textBadge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textMeta40)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.adaptive(light: .white, dark: .white.opacity(0.12)))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.borderColor.opacity(0.7), lineWidth: 1))
    }
}
