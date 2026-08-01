import AppKit
import SwiftUI

enum SettingsWindowMetrics {
    static let minWidth: CGFloat = 640
    static let minHeight: CGFloat = 420
    static let idealWidth: CGFloat = 780
    static let idealHeight: CGFloat = 580
}

/// Native `NavigationSplitView` settings shell — system Liquid Glass sidebar,
/// traffic lights, and sidebar toggle. Search lives in the sidebar header.
struct SettingsRootView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var searchText = ""

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchHits: [SettingsSearchHit] {
        SettingsSearchIndex.hits(
            query: searchText,
            storeNames: appState.stores.map(\.displayName),
            sectionTitles: SectionID.allCases.map(\.title)
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 280)
        } detail: {
            // No outer ScrollView — Stores/Sections use List, which collapses to
            // zero height when nested in an unbounded scroll container.
            detailPane(for: appState.selectedSettingsTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(appState.selectedSettingsTab.title)
                .settingsTopScrollEdgeBlur()
        }
        .frame(
            minWidth: SettingsWindowMetrics.minWidth,
            idealWidth: SettingsWindowMetrics.idealWidth,
            minHeight: SettingsWindowMetrics.minHeight,
            idealHeight: SettingsWindowMetrics.idealHeight
        )
        .background(SettingsToolbarConfigurator(paneTitle: appState.selectedSettingsTab.title))
    }

    @ViewBuilder
    private var sidebar: some View {
        Group {
            if isSearching {
                // Separate list without selection binding — avoids duplicate-tag
                // crashes when multiple hits map to the same SettingsTab.
                List {
                    if searchHits.isEmpty {
                        Text("No Results")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(searchHits) { hit in
                            Button {
                                appState.selectedSettingsTab = hit.tab
                                searchText = ""
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hit.title)
                                        .foregroundStyle(.primary)
                                    Text(hit.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                List(SettingsTab.allCases, selection: $appState.selectedSettingsTab) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            sidebarSearchField
        }
    }

    private var sidebarSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if isSearching {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func detailPane(for tab: SettingsTab) -> some View {
        switch tab {
        case .stores:
            StoresTabView()
        case .sections:
            SectionsTabView()
        case .keybindings:
            KeybindingsTabView()
        case .general:
            GeneralTabView()
        case .about:
            AboutTabView()
        }
    }
}

// MARK: - Light toolbar polish (do not replace SwiftUI's toolbar)

/// Locks icon-only mode, syncs the window title to the active pane, and suppresses
/// the titlebar hairline. Never assigns `window.toolbar` — replacing SwiftUI's
/// toolbar causes KVO crashes and can strip traffic lights / the sidebar toggle.
private struct SettingsToolbarConfigurator: NSViewRepresentable {
    var paneTitle: String

    final class Coordinator {
        var windowObservation: NSObjectProtocol?
        weak var trackedWindow: NSWindow?
        var paneTitle: String = ""

        func track(_ window: NSWindow?, paneTitle: String) {
            self.paneTitle = paneTitle
            if window !== trackedWindow {
                if let windowObservation {
                    NotificationCenter.default.removeObserver(windowObservation)
                    self.windowObservation = nil
                }
                trackedWindow = window
                guard let window else { return }
                windowObservation = NotificationCenter.default.addObserver(
                    forName: NSWindow.didUpdateNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    guard let self else { return }
                    Self.polish(self.trackedWindow, paneTitle: self.paneTitle)
                }
            }
            Self.polish(window, paneTitle: paneTitle)
        }

        deinit {
            if let windowObservation {
                NotificationCenter.default.removeObserver(windowObservation)
            }
        }

        static func polish(_ window: NSWindow?, paneTitle: String) {
            guard let window else { return }

            // Pane name in the titlebar (not the scene's static "Settings").
            if !paneTitle.isEmpty, window.title != paneTitle {
                window.title = paneTitle
            }

            window.titlebarSeparatorStyle = .none
            suppressSplitViewTitleSeparators(in: window)

            if let toolbar = window.toolbar {
                toolbar.displayMode = .iconOnly
                // Deprecated but harmless; titlebarSeparatorStyle is the modern control.
                toolbar.showsBaselineSeparator = false
                if #available(macOS 15.0, *) {
                    toolbar.allowsDisplayModeCustomization = false
                }
                for item in toolbar.items {
                    item.visibilityPriority = .user
                }
            }

            guard let root = window.contentView?.superview else { return }
            var stack: [NSView] = [root]
            while let view = stack.popLast() {
                let name = NSStringFromClass(type(of: view))

                if isTitlebarHairline(view, className: name, window: window) {
                    view.isHidden = true
                    view.alphaValue = 0
                    view.layer?.opacity = 0
                    view.setFrameSize(NSSize(width: view.frame.width, height: 0))
                }

                let overflowClass =
                    name.localizedCaseInsensitiveContains("ClippedItems")
                    || name.localizedCaseInsensitiveContains("ToolbarOverflow")
                    || name.localizedCaseInsensitiveContains("OverflowButton")
                    || name.localizedCaseInsensitiveContains("OverflowIndicator")

                var overflowButton = false
                if let button = view as? NSButton {
                    let imageDesc = button.image?.description ?? ""
                    overflowButton =
                        imageDesc.localizedCaseInsensitiveContains("chevron.forward.2")
                        || imageDesc.localizedCaseInsensitiveContains("chevron.right.2")
                        || imageDesc.localizedCaseInsensitiveContains("overflow")
                        || (button.accessibilityLabel() ?? "")
                            .localizedCaseInsensitiveContains("overflow")
                }

                if overflowClass || overflowButton {
                    hideViewerChain(from: view)
                }

                if name.contains("NSToolbarItemViewer"),
                   view.frame.minX > window.frame.width * 0.55,
                   view.frame.width > 0,
                   view.frame.width <= 60
                {
                    hideViewerChain(from: view)
                }

                stack.append(contentsOf: view.subviews)
            }
        }

        private static func isTitlebarHairline(_ view: NSView, className: String, window: NSWindow) -> Bool {
            if className.localizedCaseInsensitiveContains("TitlebarDecoration")
                || className.localizedCaseInsensitiveContains("TitlebarSeparator")
                || className.localizedCaseInsensitiveContains("ToolbarSeparator")
                || className.localizedCaseInsensitiveContains("TrackingSeparator")
            {
                return true
            }

            let frame = view.frame
            guard frame.height > 0, frame.height <= 1.5,
                  frame.width >= window.frame.width * 0.35
            else { return false }

            // Tahoe draws the titleband rule as a 1pt LayerBasedFillColorView inside
            // NSTitlebarBackgroundView — titlebarSeparatorStyle=.none does not remove it.
            if className.contains("LayerBasedFillColorView") {
                return true
            }

            var ancestor: NSView? = view.superview
            while let current = ancestor {
                let ancestorName = NSStringFromClass(type(of: current))
                if ancestorName.contains("NSTitlebarBackgroundView")
                    || ancestorName.contains("NSTitlebarContainerView")
                    || ancestorName.contains("NSTitlebarView")
                    || ancestorName.contains("NSToolbarView")
                {
                    return true
                }
                ancestor = current.superview
            }
            return false
        }

        private static func suppressSplitViewTitleSeparators(in window: NSWindow) {
            var controllers: [NSViewController] = []
            if let root = window.contentViewController {
                controllers.append(root)
            }
            var index = 0
            while index < controllers.count {
                let controller = controllers[index]
                index += 1
                controllers.append(contentsOf: controller.children)
                if let split = controller as? NSSplitViewController {
                    for item in split.splitViewItems {
                        item.titlebarSeparatorStyle = .none
                    }
                }
            }
        }

        private static func hideViewerChain(from view: NSView) {
            var node: NSView? = view
            var depth = 0
            while let current = node, depth < 8 {
                let name = NSStringFromClass(type(of: current))
                if name.contains("NSToolbarView")
                    || name.contains("NSTitlebarView")
                    || name.contains("NSThemeFrame")
                {
                    break
                }
                current.isHidden = true
                current.alphaValue = 0
                current.layer?.opacity = 0
                current.setFrameSize(.zero)
                if name.contains("NSToolbarItemViewer") { break }
                node = current.superview
                depth += 1
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.track(view.window, paneTitle: paneTitle)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.track(nsView.window, paneTitle: paneTitle)
        }
    }
}
