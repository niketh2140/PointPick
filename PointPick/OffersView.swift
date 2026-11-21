import SwiftUI
import SwiftData

struct OffersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WalletCard.addedAt) private var cards: [WalletCard]
    @State private var showAdd = false

    private var offers: [Offer] { cards.flatMap(\.offers) }
    private var saved: Double { cards.reduce(0) { $0 + $1.savedAmount } }
    private var available: Double { cards.reduce(0) { $0 + $1.availableAmount } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        stat("Saved", saved, .green)
                        Divider()
                        stat("Available", available, .blue)
                    }
                }
                ForEach(cards.filter { !$0.offers.isEmpty }) { card in
                    Section(card.name) {
                        ForEach(card.offers.sorted { ($0.expiry ?? .distantFuture) < ($1.expiry ?? .distantFuture) }) { o in
                            OfferRow(offer: o)
                        }
                        .onDelete { idx in
                            let sorted = card.offers.sorted { ($0.expiry ?? .distantFuture) < ($1.expiry ?? .distantFuture) }
                            idx.forEach { context.delete(sorted[$0]) }
                        }
                    }
                }
            }
            .overlay {
                if offers.isEmpty {
                    ContentUnavailableView("No offers yet", systemImage: "tag",
                        description: Text("Add a card from Browse — its credits show up here automatically."))
                }
            }
            .navigationTitle("Offers")
            .appList()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }.disabled(cards.isEmpty)
                }
            }
            .sheet(isPresented: $showAdd) { AddOfferView(fixedCard: nil) }
            .onAppear { offers.forEach { $0.rolloverIfNeeded() } }
        }
    }

    private func stat(_ label: String, _ v: Double, _ color: Color) -> some View {
        VStack {
            Text(v, format: .currency(code: "USD")).font(.title2.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct AddOfferView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WalletCard.addedAt) private var cards: [WalletCard]
    let fixedCard: WalletCard?
    @State private var title = ""
    @State private var amount = 10.0
    @State private var period: OfferPeriod = .once
    @State private var hasExpiry = true
    @State private var expiry = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var card: WalletCard?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title (e.g. $10 off at Whole Foods)", text: $title)
                Stepper("Amount: $\(amount.formatted())", value: $amount, in: 1...1000, step: 5)
                if fixedCard == nil {
                    Picker("Card", selection: $card) {
                        Text("Select…").tag(WalletCard?.none)
                        ForEach(cards) { Text($0.name).tag(Optional($0)) }
                    }
                }
                Picker("Repeats", selection: $period) { ForEach(OfferPeriod.allCases) { Text($0.title).tag($0) } }
                if period == .once {
                    Toggle("Has expiry", isOn: $hasExpiry)
                    if hasExpiry { DatePicker("Expires", selection: $expiry, displayedComponents: .date) }
                }
            }
            .navigationTitle("New Offer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exp: Date? = period == .once ? (hasExpiry ? expiry : nil) : period.periodEnd(containing: .now)
                        context.insert(Offer(title: title, amount: amount, period: period, expiry: exp, card: fixedCard ?? card))
                        dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || (fixedCard ?? card) == nil)
                }
            }
            .onAppear { card = card ?? cards.first }
        }
    }
}
