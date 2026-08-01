import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: "com.humanmarketing.storefront", category: "csv")

struct StoresTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var isAddingStore = false
    @State private var editingStore: Store?
    @State private var storePendingDeletion: Store?
    @State private var newDomain = ""
    @State private var newDisplayName = ""
    @State private var newColorHex = "1f6f4a"
    @State private var csvErrorMessage: String?
    @State private var isConfirmingDeleteAll = false

    var orderedStores: [Store] {
        appState.stores.sorted { $0.sortOrder < $1.sortOrder }
    }

    private enum Column {
        static let order: CGFloat = 30
        static let enable: CGFloat = 40
        static let accent: CGFloat = 40
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer(minLength: 0)
                Button(allVisible ? "Hide All" : "Show All", action: toggleAllVisibility)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 0) {
                tableHeader
                Divider().overlay(Theme.hairline)
                List {
                    ForEach(orderedStores) { store in
                        storeRow(store: store)
                            .listRowBackground(Theme.settingsCardFill)
                    }
                    .onMove(perform: moveStores)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .settingsTopScrollEdgeBlur()
            }
            .background(Theme.settingsCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.borderColor, lineWidth: 1))

            HStack(spacing: 14) {
                SettingsTextLink("＋ Add store", action: beginAdding)
                SettingsTextLink("Import CSV", action: importCSV)
                SettingsTextLink("Export CSV", action: exportCSV)
                Spacer()
                SettingsTextLink(
                    "Delete All",
                    isEnabled: !appState.stores.isEmpty,
                    isDestructive: true
                ) {
                    isConfirmingDeleteAll = true
                }
            }

            Spacer()
        }
        .padding(18)
        .sheet(isPresented: $isAddingStore) {
            storeSheet(title: "Add a store", confirmTitle: "Add", store: nil, domain: $newDomain, displayName: $newDisplayName, colorBinding: newColorBinding) {
                addStore()
            } onCancel: {
                isAddingStore = false
            }
        }
        .sheet(item: $editingStore) { store in
            storeSheet(title: "Edit store", confirmTitle: "Save", store: store, domain: $newDomain, displayName: $newDisplayName, colorBinding: colorBinding(for: store)) {
                saveEdits(to: store)
            } onCancel: {
                editingStore = nil
            }
        }
        .deleteConfirmation(pendingStore: $storePendingDeletion, appState: appState, editingStore: $editingStore)
        .confirmationDialog(
            "Delete all \(appState.stores.count) stores?",
            isPresented: $isConfirmingDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) { deleteAllStores() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone. Export a CSV first if you want to restore this list later.")
        }
        .alert("Couldn't complete that", isPresented: Binding(
            get: { csvErrorMessage != nil },
            set: { if !$0 { csvErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { csvErrorMessage = nil }
        } message: {
            Text(csvErrorMessage ?? "")
        }
    }

    private var allVisible: Bool {
        appState.stores.allSatisfy(\.isVisible)
    }

    private func toggleAllVisibility() {
        let newValue = !allVisible
        for index in appState.stores.indices {
            appState.stores[index].isVisible = newValue
        }
        appState.save()
    }

    /// Column labels for the store list below — kept as a separate row above the
    /// (still-native, still-reorderable-by-drag) `List` rather than a `List` section
    /// header, so it stays fixed in place while the list scrolls beneath it.
    private var tableHeader: some View {
        HStack(spacing: 10) {
            Text("Order")
                .frame(width: Column.order, alignment: .leading)
            Text("Enable")
                .frame(width: Column.enable, alignment: .leading)
            Text("Accent")
                .frame(width: Column.accent, alignment: .leading)
            Text("Display name")
            Spacer(minLength: 12)
        }
        .font(.system(size: 9.5, weight: .semibold))
        .foregroundStyle(Theme.textMeta40)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
    }

    private func storeRow(store: Store) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(Theme.textMeta25)
                .frame(width: Column.order, alignment: .leading)

            Button {
                toggleVisibility(store)
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(store.isVisible ? Theme.accent : Theme.settingsCardFill)
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(store.isVisible ? .clear : Theme.borderColor, lineWidth: 1)
                    )
                    .overlay {
                        if store.isVisible {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
            }
            .buttonStyle(.plain)
            .frame(width: Column.enable, alignment: .leading)

            colorSwatch(color: colorBinding(for: store))
                .frame(width: Column.accent, alignment: .leading)

            Text(store.displayName)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textPrimary)

            Spacer(minLength: 12)

            Button {
                beginEditing(store)
            } label: {
                Image("EditIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textMeta40)

            Button {
                storePendingDeletion = store
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textMeta40)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .opacity(store.isVisible ? 1 : 0.5)
    }

    private func colorSwatch(color: Binding<Color>) -> some View {
        // ColorPicker always draws a rounded-rect well with its own chrome. Clipping that
        // rect to a circle leaves the well's top/bottom edges as flat grey chords —
        // scale the control up so those edges fall outside the mask.
        ColorPicker("", selection: color, supportsOpacity: false)
            .labelsHidden()
            .scaleEffect(1.8)
            .frame(width: 20, height: 20)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.borderColor, lineWidth: 1))
            .contentShape(Circle())
    }

    private func deleteAllStores() {
        appState.stores.removeAll()
        appState.save()
    }

    private func toggleVisibility(_ store: Store) {
        guard let index = appState.stores.firstIndex(where: { $0.id == store.id }) else { return }
        appState.stores[index].isVisible.toggle()
        appState.save()
    }

    private func moveStores(from source: IndexSet, to destination: Int) {
        appState.moveStore(fromOffsets: source, toOffset: destination)
    }

    private func colorBinding(for store: Store) -> Binding<Color> {
        Binding(
            get: { store.color },
            set: { newColor in
                guard let index = appState.stores.firstIndex(where: { $0.id == store.id }) else { return }
                appState.stores[index].colorHex = newColor.hexString
                appState.save()
            }
        )
    }

    private func beginEditing(_ store: Store) {
        newDisplayName = store.displayName
        newDomain = store.myshopifyDomain
        editingStore = store
    }

    private func beginAdding() {
        let palette = ["1f6f4a", "c07a2c", "3a6ea8", "7a4b8c", "4a7a5c", "a8563a"]
        newColorHex = palette[appState.stores.count % palette.count]
        isAddingStore = true
    }

    private var newColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: newColorHex) },
            set: { newColorHex = $0.hexString }
        )
    }

    private func storeSheet(
        title: String,
        confirmTitle: String,
        store: Store?,
        domain: Binding<String>,
        displayName: Binding<String>,
        colorBinding: Binding<Color>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Store URL")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                TextField("mystore.myshopify.com", text: domain)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Display name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                TextField("Display name", text: displayName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Color")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    colorSwatch(color: colorBinding)
                    Text("Click the swatch to change it")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            HStack {
                if let store {
                    Button("Delete…", role: .destructive) {
                        storePendingDeletion = store
                    }
                }
                Spacer()
                Button("Cancel", action: onCancel)
                Button(confirmTitle, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(domain.wrappedValue.isEmpty || displayName.wrappedValue.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        // Attached here too (not just on the outer body): a `.confirmationDialog`
        // can only present over whichever presentation layer it's attached to, and
        // while this sheet is up, the outer body's copy is behind it and can't
        // surface until the sheet dismisses.
        .deleteConfirmation(pendingStore: $storePendingDeletion, appState: appState, editingStore: $editingStore)
    }

    private func addStore() {
        var domain = newDomain.trimmingCharacters(in: .whitespaces)
        if !domain.hasSuffix(".myshopify.com") {
            domain = domain.replacingOccurrences(of: ".myshopify.com", with: "") + ".myshopify.com"
        }
        appState.addStore(domain: domain, displayName: newDisplayName, colorHex: newColorHex)
        newDomain = ""
        newDisplayName = ""
        isAddingStore = false
    }

    private func saveEdits(to store: Store) {
        var domain = newDomain.trimmingCharacters(in: .whitespaces)
        if !domain.hasSuffix(".myshopify.com") {
            domain = domain.replacingOccurrences(of: ".myshopify.com", with: "") + ".myshopify.com"
        }
        guard let index = appState.stores.firstIndex(where: { $0.id == store.id }) else {
            editingStore = nil
            return
        }
        appState.stores[index].displayName = newDisplayName
        appState.stores[index].myshopifyDomain = domain
        appState.save()
        editingStore = nil
    }

    // MARK: - CSV import/export

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "storefront-stores.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try appState.storesCSV().write(to: url, atomically: true, encoding: .utf8)
        } catch {
            logger.error("CSV export failed: \(error.localizedDescription, privacy: .public)")
            csvErrorMessage = "Couldn't save the CSV file: \(error.localizedDescription)"
        }
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            appState.importStoresCSV(contents)
        } catch {
            logger.error("CSV import failed: \(error.localizedDescription, privacy: .public)")
            csvErrorMessage = "Couldn't read that file — make sure it's a valid UTF-8 CSV."
        }
    }
}

private extension View {
    /// Applied at both the outer Stores list and inside the edit sheet, since a
    /// `.confirmationDialog` only presents over the layer it's attached to.
    func deleteConfirmation(pendingStore: Binding<Store?>, appState: AppState, editingStore: Binding<Store?>) -> some View {
        confirmationDialog(
            "Remove \(pendingStore.wrappedValue?.displayName ?? "this store")?",
            isPresented: Binding(
                get: { pendingStore.wrappedValue != nil },
                set: { if !$0 { pendingStore.wrappedValue = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let store = pendingStore.wrappedValue {
                    appState.removeStore(store)
                }
                pendingStore.wrappedValue = nil
                editingStore.wrappedValue = nil
            }
            Button("Cancel", role: .cancel) {
                pendingStore.wrappedValue = nil
            }
        } message: {
            Text("This removes it from Storefront only. Your Shopify store itself isn't affected.")
        }
    }
}

/// Plain text action link for Settings footers — no pill chrome.
private struct SettingsTextLink: View {
    let title: String
    var isEnabled: Bool = true
    var isDestructive: Bool = false
    let action: () -> Void

    init(
        _ title: String,
        isEnabled: Bool = true,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.action = action
    }

    private var textColor: Color {
        guard isEnabled else { return Theme.textMeta40 }
        return isDestructive ? .red : Color.accentColor
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(textColor)
            .disabled(!isEnabled)
    }
}
