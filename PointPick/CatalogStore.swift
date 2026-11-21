import Foundation
import Observation

struct CatalogFile: Codable {
    var version: Int
    var updated: String
    var cards: [CatalogCard]
}

/// Loads the card catalog: cached remote copy if present, otherwise the bundled one.
/// `refresh()` downloads a newer catalog from the configured URL (https or file URL).
@MainActor @Observable
final class CatalogStore {
    static let shared = CatalogStore()

    private(set) var cards: [CatalogCard] = []
    private(set) var version = 0
    private(set) var updated = ""
    private(set) var isRefreshing = false
    private(set) var lastError: String?
    private(set) var source = "Bundled"

    static let urlKey = "catalogURL"
    static let defaultURL = "https://raw.githubusercontent.com/niketh2140/pointpick-catalog/main/PointPick/cards.json"
    var remoteURLString: String {
        get { UserDefaults.standard.string(forKey: Self.urlKey) ?? Self.defaultURL }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.urlKey) }
    }

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("catalog-cache.json")
    }

    init() { loadLocal() }

    private func apply(_ f: CatalogFile, source: String) {
        cards = f.cards; version = f.version; updated = f.updated; self.source = source
    }

    private func loadLocal() {
        let dec = JSONDecoder()
        let bundled = Bundle.main.url(forResource: "cards", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }.flatMap { try? dec.decode(CatalogFile.self, from: $0) }
        let cached = (try? Data(contentsOf: cacheURL)).flatMap { try? dec.decode(CatalogFile.self, from: $0) }
        // Prefer whichever is newer.
        if let c = cached, c.version >= (bundled?.version ?? 0) { apply(c, source: "Downloaded") }
        else if let b = bundled { apply(b, source: "Bundled") }
    }

    func refresh() async {
        guard let url = URL(string: remoteURLString), !remoteURLString.isEmpty else {
            lastError = "No catalog URL set."; return
        }
        isRefreshing = true; lastError = nil
        defer { isRefreshing = false }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                lastError = "Server returned \(http.statusCode)."; return
            }
            let file = try JSONDecoder().decode(CatalogFile.self, from: data)
            guard !file.cards.isEmpty else { lastError = "Catalog was empty."; return }
            guard file.version >= version else { return }   // never downgrade
            try data.write(to: cacheURL, options: .atomic)
            apply(file, source: "Downloaded")
        } catch {
            lastError = "Couldn't update: \(error.localizedDescription)"
        }
    }
}
