import SwiftUI
import SwiftData

struct MyCardsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WalletCard.addedAt) private var cards: [WalletCard]
    @State private var showCustom = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(cards) { card in
                    NavigationLink(value: card) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.name).font(.headline)
                            Text("\(card.issuer) · $\(card.annualFee, specifier: "%.0f") fee").font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Text("\(card.availableAmount, format: .currency(code: "USD")) available").foregroundStyle(.blue)
                                Text("·")
                                Text("\(card.savedAmount, format: .currency(code: "USD")) saved").foregroundStyle(.green)
                            }.font(.caption)
                        }
                    }
                }
                .onDelete { idx in idx.forEach { context.delete(cards[$0]) } }
            }
            .overlay {
                if cards.isEmpty {
                    ContentUnavailableView("No cards yet", systemImage: "creditcard",
                        description: Text("Add cards from the Browse tab, or tap + to enter a custom card."))
                }
            }
            .navigationTitle("Cards")
            .appList()
            .navigationDestination(for: WalletCard.self) { MyCardDetailView(card: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCustom = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showCustom) { CustomCardView(onSave: {}) }
            .onAppear { cards.flatMap(\.offers).forEach { $0.rolloverIfNeeded() } }
        }
    }
}

struct MyCardDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let card: WalletCard
    @State private var showAddOffer = false
    @State private var confirmRemove = false

    private var offers: [Offer] {
        card.offers.sorted { ($0.expiry ?? .distantFuture) < ($1.expiry ?? .distantFuture) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    stat("Available", card.availableAmount, .blue)
                    Divider()
                    stat("Saved", card.savedAmount, .green)
                    Divider()
                    stat("Fee", card.annualFee, .orange)
                }
            }
            Section("Offers & credits") {
                ForEach(offers) { o in OfferRow(offer: o) }
                    .onDelete { idx in idx.forEach { context.delete(offers[$0]) } }
                Button { showAddOffer = true } label: { Label("Add offer", systemImage: "plus.circle") }
            }
            Section {
                Toggle("Set card open date", isOn: Binding(
                    get: { card.openedDate != nil },
                    set: { card.openedDate = $0 ? (card.openedDate ?? .now) : nil; card.applyOpenedDate() }))
                if let d = card.openedDate {
                    DatePicker("Opened", selection: Binding(get: { d }, set: { card.openedDate = $0; card.applyOpenedDate() }),
                               in: ...Date.now, displayedComponents: .date)
                } else if card.offers.contains(where: \.anniversary) {
                    Text("Set when you opened this card so anniversary credits reset on the right date.")
                        .font(.footnote).foregroundStyle(.orange)
                }
            } header: { Text("Card anniversary") }
            let bonus = card.rates.filter { $0.value > card.baseRate }.sorted { $0.value > $1.value }
            Section("Earn rates") {
                LabeledContent("Everything else", value: "\(card.baseRate.formatted())x")
                ForEach(bonus, id: \.key) { k, v in
                    LabeledContent(k.capitalized, value: "\(v.formatted())x")
                }
            }
            Section {
                Button("Remove from My Cards", role: .destructive) { confirmRemove = true }
            }
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .appList()
        .onAppear { card.offers.forEach { $0.rolloverIfNeeded() } }
        .sheet(isPresented: $showAddOffer) { AddOfferView(fixedCard: card) }
        .confirmationDialog("Remove this card and its offers?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { context.delete(card); dismiss() }
        }
    }

    private func stat(_ label: String, _ v: Double, _ color: Color) -> some View {
        VStack {
            Text(v, format: .currency(code: "USD")).font(.headline).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct OfferRow: View {
    let offer: Offer
    var showCard = false
    @State private var showUsage = false

    var body: some View {
        HStack(alignment: .top) {
            Button { offer.toggleUsed() } label: {
                Image(systemName: offer.used ? "checkmark.square.fill" : "square")
                    .font(.title2).foregroundStyle(offer.used ? Color.green : .secondary)
            }.buttonStyle(.borderless)
            VStack(alignment: .leading, spacing: 3) {
                Text(offer.title).strikethrough(offer.used).font(.body)
                Text([showCard ? offer.card?.name : nil, offer.period == .once ? nil : offer.period.title, offer.note.isEmpty ? nil : offer.note]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
                if offer.usedAmount > 0 && !offer.used {
                    ProgressView(value: offer.usedAmount, total: offer.amount).tint(Theme.accent)
                    Text("\(offer.usedAmount, format: .currency(code: "USD")) of \(offer.amount, format: .currency(code: "USD")) used")
                        .font(.caption2).foregroundStyle(Theme.accent)
                }
                if offer.needsActivation {
                    Button { offer.activated.toggle() } label: {
                        Label(offer.activated ? "Activated" : "Needs activation",
                              systemImage: offer.activated ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(offer.activated ? .green : .orange)
                    }.buttonStyle(.borderless)
                }
                if offer.redeemedCount > 0 { Text("Used \(offer.redeemedCount)×").font(.caption2).foregroundStyle(.green) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(offer.amount, format: .currency(code: "USD")).font(.headline)
                if offer.hasEnded {
                    Text("Ended").font(.caption2).foregroundStyle(.red)
                } else if let e = offer.expiry {
                    Text(offer.isExpired ? "Expired" : (offer.used ? "Resets \(e.addingTimeInterval(1).formatted(.dateTime.month().day()))" : "Exp \(e.formatted(.dateTime.month().day()))"))
                        .font(.caption2).foregroundStyle(offer.isExpired ? .red : .secondary)
                }
                Button { showUsage = true } label: { Text("Track $").font(.caption2.weight(.semibold)) }
                    .buttonStyle(.borderless)
            }
        }
        .sheet(isPresented: $showUsage) { UsageSheet(offer: offer) }
    }
}

struct UsageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let offer: Offer
    @State private var value: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section(offer.title) {
                    Stepper("Used: \(value, format: .currency(code: "USD"))", value: $value, in: 0...offer.amount, step: offer.amount > 100 ? 25 : 5)
                    Slider(value: $value, in: 0...offer.amount)
                    Text("Remaining this period: \(max(0, offer.amount - value), format: .currency(code: "USD"))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Track usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { offer.setUsedAmount(value); dismiss() } }
            }
            .onAppear { value = offer.usedAmount }
        }
        .presentationDetents([.medium])
    }
}

struct CustomCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var onSave: () -> Void
    @State private var name = ""
    @State private var issuer = ""
    @State private var base = 1.0
    @State private var pointValue = 1.0
    @State private var fee = 0.0
    @State private var rates: [SpendCategory: Double] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    TextField("Name", text: $name)
                    TextField("Issuer", text: $issuer)
                    Stepper("Base rate: \(base.formatted())x", value: $base, in: 0...10, step: 0.5)
                    Stepper("Point value: \(pointValue.formatted())¢", value: $pointValue, in: 0.5...5, step: 0.1)
                    Stepper("Annual fee: $\(fee.formatted())", value: $fee, in: 0...1000, step: 25)
                }
                Section("Category bonuses") {
                    ForEach(SpendCategory.allCases.filter { $0 != .other }) { c in
                        Stepper("\(c.title): \((rates[c] ?? base).formatted())x",
                                value: Binding(get: { rates[c] ?? base }, set: { rates[c] = $0 }),
                                in: 0...10, step: 0.5)
                    }
                }
            }
            .navigationTitle("Custom Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let r = Dictionary(uniqueKeysWithValues: rates.map { ($0.key.rawValue, $0.value) })
                        context.insert(WalletCard(name: name, issuer: issuer.isEmpty ? "Custom" : issuer,
                                                  baseRate: base, pointValueCents: pointValue, annualFee: fee, rates: r))
                        dismiss(); onSave()
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
