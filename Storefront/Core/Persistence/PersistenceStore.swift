import Foundation

final class PersistenceStore {
    static let shared = PersistenceStore()

    private let directoryURL: URL
    private let storesURL: URL
    private let settingsURL: URL

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directoryURL = appSupport.appendingPathComponent("Storefront", isDirectory: true)
        storesURL = directoryURL.appendingPathComponent("stores.json")
        settingsURL = directoryURL.appendingPathComponent("settings.json")
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func loadStores() -> [Store] {
        guard let data = try? Data(contentsOf: storesURL) else {
            return SampleData.stores
        }
        return (try? JSONDecoder().decode([Store].self, from: data)) ?? SampleData.stores
    }

    func save(stores: [Store]) {
        guard let data = try? JSONEncoder().encode(stores) else { return }
        try? data.write(to: storesURL, options: .atomic)
    }

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL) else {
            return AppSettings()
        }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func save(settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }
}
