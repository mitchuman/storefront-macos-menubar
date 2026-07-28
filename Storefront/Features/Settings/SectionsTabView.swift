import SwiftUI

/// One global list — enable/disable and reorder apply to every store. (An earlier version
/// let toggles override individual stores via a picker, but that only ever visibly
/// affected whichever store happened to be selected, which read as broken.)
struct SectionsTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SECTIONS")
                .font(.mono(10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMeta40)

            List {
                ForEach(appState.settings.sectionOrder, id: \.self) { section in
                    HStack(spacing: 11) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(Theme.textMeta25)
                        Text(section.title)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Toggle("", isOn: bindingFor(section: section))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(Theme.settingsCardFill)
                }
                .onMove(perform: move)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.settingsCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.borderColor, lineWidth: 1))

            Text("Applies to every store. Drag rows to reorder.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(18)
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
