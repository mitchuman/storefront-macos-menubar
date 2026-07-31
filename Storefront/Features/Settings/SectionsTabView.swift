import SwiftUI

/// One global list — enable/disable and reorder apply to every store. (An earlier version
/// let toggles override individual stores via a picker, but that only ever visibly
/// affected whichever store happened to be selected, which read as broken.)
struct SectionsTabView: View {
    @EnvironmentObject var appState: AppState

    private var allEnabled: Bool {
        appState.settings.enabledSections.count == SectionID.allCases.count
    }

    private func toggleAllEnabled() {
        appState.settings.enabledSections = allEnabled ? [] : Set(SectionID.allCases)
        appState.save()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer(minLength: 0)
                Button(allEnabled ? "Disable All" : "Enable All", action: toggleAllEnabled)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            List {
                ForEach(appState.settings.sectionOrder, id: \.self) { section in
                    HStack(spacing: 11) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(Theme.textMeta25)
                        Image(section.iconName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Theme.textMeta40)
                        Text(section.title)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Toggle("", isOn: bindingFor(section: section))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .listRowBackground(Theme.settingsCardFill)
                }
                .onMove(perform: move)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.settingsCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.borderColor, lineWidth: 1))

            HStack {
                Text("Applies to every store. Drag rows to reorder.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("Reset to Default", action: resetToDefault)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(18)
    }

    private func resetToDefault() {
        appState.settings.sectionOrder = SectionID.defaultOrder
        appState.settings.enabledSections = Set(SectionID.allCases)
        appState.save()
    }

    private func bindingFor(section: SectionID) -> Binding<Bool> {
        Binding(
            get: { appState.settings.enabledSections.contains(section) },
            set: { newValue in
                if newValue {
                    appState.settings.enabledSections.insert(section)
                } else {
                    appState.settings.enabledSections.remove(section)
                }
                appState.save()
            }
        )
    }

    private func move(from source: IndexSet, to destination: Int) {
        appState.settings.sectionOrder.move(fromOffsets: source, toOffset: destination)
        appState.save()
    }
}
