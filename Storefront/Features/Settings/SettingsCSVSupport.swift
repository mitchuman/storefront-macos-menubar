import AppKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// Shared by the Stores and Sections panes, which both import/export CSV.
let settingsCSVLogger = Logger(subsystem: "com.humanmarketing.storefront", category: "csv")

/// The sandbox-friendly file pickers behind Settings' CSV import/export. Both panes had
/// their own copy of this boilerplate, twice each.
enum CSVFilePanel {
    /// Destination for an export, or `nil` if the user cancelled.
    static func exportURL(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// Source for an import, or `nil` if the user cancelled.
    static func importURL() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}

extension View {
    /// Presents a CSV failure message, clearing it on dismiss. Shown as an alert since
    /// these are user-actionable ("that file isn't valid UTF-8 CSV").
    func csvErrorAlert(_ message: Binding<String?>) -> some View {
        alert("Couldn't complete that", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
