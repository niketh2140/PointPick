import SwiftUI
import SwiftData

struct BestCardView: View {
    @Query(sort: \WalletCard.addedAt) private var cards: [WalletCard]
    @State private var category: SpendCategory = .dining
    @State private var store = ""

    private var effectiveCategory: SpendCategory { SpendCategory.match(store: store) ?? category }

    private var ranked: [WalletCard] {
        cards.sorted { $0.valuePercent(for: effectiveCategory) > $1.valuePercent(for: effectiveCategory) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Where are you spending?") {
                    TextField("Search a store (e.g. Starbucks)", text: $store)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(SpendCategory.allCases) { c in
                                Button {
                                    category = c; store = ""
                                } label: {
                                    Label(c.title, systemImage: c.icon)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(c == effectiveCategory ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.white.opacity(0.08)), in: Capsule())
                                        .foregroundStyle(c == effectiveCategory ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !store.isEmpty {
                        Text(SpendCategory.match(store: store) == nil
                             ? "Unknown store — showing \(category.title)"
                             : "Detected category: \(effectiveCategory.title)")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Your cards, best first") {
                    if cards.isEmpty {
                        ContentUnavailableView("No cards yet", systemImage: "creditcard",
                                               description: Text("Add cards in the Wallet tab."))
                    }
                    ForEach(Array(ranked.enumerated()), id: \.element.persistentModelID) { i, card in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(card.name).font(.headline)
                                    if i == 0 { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                                }
                                Text(card.issuer).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(String(format: "%gx", card.multiplier(for: effectiveCategory))).font(.headline)
                                Text(String(format: "%.1f%% value", card.valuePercent(for: effectiveCategory)))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pointers")
            .appList()
        }
    }
}
