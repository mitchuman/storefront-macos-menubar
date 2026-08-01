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
    @State private var draggingStoreID: Store.ID?

    var orderedStores: [Store] {
        appState.stores.sorted { $0.sortOrder < $1.sortOrder }
    }

    private enum Column {
        static let order: CGFloat = SettingsRowMetrics.reorderWidth
        static let accent: CGFloat = 20
        static let spacing: CGFloat = SettingsRowMetrics.rowSpacing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Drag rows to reorder. Hidden stores stay out of the panel.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                    Button(allVisible ? "Hide All" : "Show All", action: toggleAllVisibility)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 0) {
                    ForEach(orderedStores) { store in
                        storeRow(store: store)
                            .onDrag {
                                draggingStoreID = store.id
                                return NSItemProvider(object: store.id.uuidString as NSString)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: StoreReorderDropDelegate(
                                    targetID: store.id,
                                    orderedIDs: orderedStores.map(\.id),
                                    draggingStoreID: $draggingStoreID,
                                    onMove: { from, to in
                                        reorderStores(from: from, to: to, save: false)
                                    },
                                    onDrop: {
                                        appState.save()
                                    }
                                )
                            )
                    }

                    if !orderedStores.isEmpty {
                        SettingsGroupedDivider(leadingInset: SettingsRowMetrics.afterReorderSeparatorLeading)
                    }

                    Button(action: beginAdding) {
                        HStack(spacing: Column.spacing) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: Column.order, alignment: .leading)
                            Text("Add Store")
                                .font(.system(size: 12.5))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(Theme.settingsCardFill)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.borderColor, lineWidth: 1))

                HStack(spacing: 14) {
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
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .settingsTopScrollEdgeBlur()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private func storeRow(store: Store) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Column.spacing) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMeta25)
                    .frame(width: Column.order, alignment: .leading)

                colorSwatch(color: colorBinding(for: store))
                    .frame(width: Column.accent, alignment: .leading)

                Text(store.displayName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textPrimary)

                Spacer(minLength: 12)

                Button {
                    appState.toggleFavorite(store)
                } label: {
                    Image(systemName: store.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.isFavorite ? Theme.textPrimary : Theme.textMeta40)

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

                Toggle("", isOn: visibilityBinding(for: store))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
            .padding(.vertical, 9)
            .opacity(store.isVisible ? (draggingStoreID == store.id ? 0.45 : 1) : 0.5)

            if store.id != orderedStores.last?.id {
                SettingsGroupedDivider(leadingInset: SettingsRowMetrics.afterReorderSeparatorLeading)
            }
        }
    }

    private func visibilityBinding(for store: Store) -> Binding<Bool> {
        Binding(
            get: { store.isVisible },
            set: { newValue in
                guard let index = appState.stores.firstIndex(where: { $0.id == store.id }) else { return }
                appState.stores[index].isVisible = newValue
                appState.save()
            }
        )
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

    private func reorderStores(from: Int, to: Int, save: Bool) {
        var ordered = orderedStores
        ordered.move(fromOffsets: IndexSet(integer: from), toOffset: to)
        for (index, store) in ordered.enumerated() {
            guard let idx = appState.stores.firstIndex(where: { $0.id == store.id }) else { continue }
            appState.stores[idx].sortOrder = index
        }
        if save {
            appState.save()
        }
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

// MARK: - Drag reorder

private struct StoreReorderDropDelegate: DropDelegate {
    let targetID: Store.ID
    let orderedIDs: [Store.ID]
    @Binding var draggingStoreID: Store.ID?
    let onMove: (_ from: Int, _ to: Int) -> Void
    let onDrop: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggingStoreID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggingStoreID,
              draggingStoreID != targetID,
              let from = orderedIDs.firstIndex(of: draggingStoreID),
              let to = orderedIDs.firstIndex(of: targetID)
        else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            onMove(from, to > from ? to + 1 : to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingStoreID = nil
        onDrop()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
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
