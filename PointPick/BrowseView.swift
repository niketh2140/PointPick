import SwiftUI
import SwiftData

struct BrowseView: View {
    @State private var store = CatalogStore.shared
    @State private var showSource = false
    @Environment(\.modelContext) private var context
    @Query private var owned: [WalletCard]
    @State private var search = ""
    @State private var issuer = "All"
    @State private var segment = "personal"
    @State private var sort: Sort = .name

    enum Sort: String, CaseIterable, Identifiable {
        case name = "Name", fee = "Annual fee", credits = "Credits value"
        var id: String { rawValue }
    }

    private var issuers: [String] { ["All"] + Set(store.cards.filter { $0.segment == segment }.map(\.issuer)).sorted() }

    private var results: [CatalogCard] {
        store.cards
            .filter { $0.segment == segment }
            .filter { issuer == "All" || $0.issuer == issuer }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.issuer.localizedCaseInsensitiveContains(search) }
            .sorted {
                switch sort {
                case .name: $0.name < $1.name
                case .fee: $0.annualFee < $1.annualFee
                case .credits: $0.annualCreditValue > $1.annualCreditValue
                }
            }
    }

    private var groups: [(String, [CatalogCard])] {
        Dictionary(grouping: results, by: \.issuer).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private func isOwned(_ c: CatalogCard) -> Bool { owned.contains { $0.catalogID == c.id } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Type", selection: $segment) {
                        Text("Personal").tag("personal")
                        Text("Business").tag("business")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: segment) { issuer = "All" }
                }
                .listRowBackground(Color.clear)
                ForEach(groups, id: \.0) { name, list in
                    Section {
                        ForEach(list) { c in
                            NavigationLink(value: c) {
                                CatalogRow(card: c, owned: isOwned(c)) { add(c) }
                            }
                        }
                    } header: {
                        Text("\(name) · \(list.count)")
                    }
                }
                Section {} footer: {
                    Text("\(results.count) cards · catalog v\(store.version) (\(store.updated), \(store.source)). Terms change often — cards marked unverified may be out of date.")
                }
            }
            .navigationTitle("Search")
            .appList()
            .searchable(text: $search, prompt: "Search cards or issuers")
            .refreshable { await store.refresh() }
            .task { if !store.remoteURLString.isEmpty { await store.refresh() } }
            .sheet(isPresented: $showSource) { CatalogSourceView() }
            .navigationDestination(for: CatalogCard.self) { c in
                CatalogDetailView(card: c, owned: isOwned(c)) { add(c) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Issuer", selection: $issuer) { ForEach(issuers, id: \.self) { Text($0) } }
                        Picker("Sort", selection: $sort) { ForEach(Sort.allCases) { Text($0.rawValue).tag($0) } }
                        Button("Catalog source…", systemImage: "icloud.and.arrow.down") { showSource = true }
                    } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                }
            }
        }
    }

    private func add(_ c: CatalogCard) {
        guard !isOwned(c) else { return }
        context.insert(WalletCard(c))
    }
}

struct CatalogRow: View {
    let card: CatalogCard
    let owned: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.name).font(.headline)
                Text("\(card.issuer) · $\(card.annualFee, specifier: "%.0f") fee").font(.caption).foregroundStyle(.secondary)
                if card.status != "verified" {
                    Text(card.status == "partial" ? "Partially verified" : "Unverified").font(.caption2).foregroundStyle(.orange)
                }
                if !card.topRates.isEmpty {
                    Text(card.topRates.prefix(3).map { "\($0.0.title) \($0.1.formatted())x" }.joined(separator: " · "))
                        .font(.caption2).foregroundStyle(.tint)
                }
                if !card.credits.isEmpty {
                    Text("\(card.credits.count) credits · ~$\(card.annualCreditValue, specifier: "%.0f")/yr")
                        .font(.caption2).foregroundStyle(.green)
                }
            }
            Spacer()
            Button(action: onAdd) {
                Image(systemName: owned ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2).foregroundStyle(owned ? .green : .accentColor)
            }
            .buttonStyle(.borderless).disabled(owned)
        }
    }
}

struct CatalogDetailView: View {
    let card: CatalogCard
    let owned: Bool
    let onAdd: () -> Void

    var body: some View {
        List {
            Section {
                LabeledContent("Data status", value: card.status.capitalized)
                if let s = card.source, let u = URL(string: s) { Link("Source", destination: u) }
                LabeledContent("Issuer", value: card.issuer)
                LabeledContent("Annual fee", value: card.annualFee, format: .currency(code: "USD"))
                LabeledContent("Base earn", value: "\(card.baseRate.formatted())x")
                LabeledContent("Point value", value: "\(card.pointValueCents.formatted())¢")
            }
            Section("Earn rates") {
                ForEach(card.topRates, id: \.0) { cat, rate in
                    HStack { Label(cat.title, systemImage: cat.icon); Spacer(); Text("\(rate.formatted())x").bold() }
                }
                if card.topRates.isEmpty { Text("Flat \(card.baseRate.formatted())x on everything").foregroundStyle(.secondary) }
            }
            if !card.credits.isEmpty {
                Section("Credits & offers you can track") {
                    ForEach(card.credits, id: \.self) { cr in
                        VStack(alignment: .leading) {
                            HStack { Text(cr.title); Spacer(); Text(cr.amount, format: .currency(code: "USD")).bold() }
                            Text(cr.period.title + (cr.note.isEmpty ? "" : " · \(cr.note)"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .appList()
        .safeAreaInset(edge: .bottom) {
            Button(action: onAdd) {
                Label(owned ? "In My Cards" : "Add to My Cards", systemImage: owned ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity).padding()
            }
            .buttonStyle(.borderedProminent).disabled(owned).padding()
        }
    }
}

struct CatalogSourceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = CatalogStore.shared
    @State private var url = CatalogStore.shared.remoteURLString

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://…/cards.json", text: $url)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                } header: { Text("Catalog URL") } footer: {
                    Text("Point this at a hosted cards.json (same format as the bundled one). Pull down on Search to refresh.")
                }
                Section {
                    LabeledContent("Version", value: "\(store.version)")
                    LabeledContent("Updated", value: store.updated)
                    LabeledContent("Using", value: store.source)
                    LabeledContent("Cards", value: "\(store.cards.count)")
                    if let e = store.lastError { Text(e).foregroundStyle(.red).font(.footnote) }
                }
                Section {
                    Button(store.isRefreshing ? "Updating…" : "Update now") {
                        store.remoteURLString = url
                        Task { await store.refresh() }
                    }.disabled(store.isRefreshing)
                }
            }
            .navigationTitle("Catalog Source")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { store.remoteURLString = url; dismiss() } } }
        }
    }
}
