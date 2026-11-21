import SwiftUI
import SwiftData

struct ForYouView: View {
    @Query(sort: \WalletCard.addedAt) private var cards: [WalletCard]
    @Binding var tab: AppTab

    private var offers: [Offer] { cards.flatMap(\.offers) }
    private var active: [Offer] { offers.filter { !$0.used && !$0.isExpired && $0.remaining > 0 } }
    private var fees: Double { cards.reduce(0) { $0 + $1.annualFee } }
    private var saved: Double { cards.reduce(0) { $0 + $1.savedAmount } }
    private var byIssuer: [(String, Int, Double)] {
        Dictionary(grouping: cards, by: \.issuer).map { k, v in
            let a = v.flatMap(\.offers).filter { !$0.used && !$0.isExpired }
            return (k, a.count, a.reduce(0) { $0 + $1.remaining })
        }.sorted { $0.0 < $1.0 }
    }
    private var soonest: [Offer] {
        active.filter { $0.expiry != nil }.sorted { $0.expiry! < $1.expiry! }.prefix(3).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        SectionTitle("Account Summary")
                        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                            GridRow {
                                stat("\(cards.count)", "Active Cards")
                                stat(fees.formatted(.currency(code: "USD").precision(.fractionLength(0))), "Card Fees")
                            }
                            GridRow {
                                stat("\(active.count)", "Active Offers")
                                stat(active.reduce(0) { $0 + $1.remaining }.formatted(.currency(code: "USD").precision(.fractionLength(0))), "Offer Value")
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        SectionTitle("Shortcuts")
                        HStack(spacing: 10) {
                            shortcut("Best Card", "creditcard.fill", .pointers)
                            shortcut("Add Card", "plus.circle.fill", .search)
                            shortcut("Offers", "tag.fill", .offers)
                        }
                    }

                    if !soonest.isEmpty {
                        VStack(spacing: 10) {
                            SectionTitle("Expiring Soon")
                            Tile {
                                VStack(spacing: 12) {
                                    ForEach(soonest) { o in
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(o.title).font(.subheadline.weight(.semibold))
                                                Text(o.card?.name ?? "").font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing) {
                                                Text(o.amount, format: .currency(code: "USD")).font(.subheadline.bold())
                                                Text(o.expiry!.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        SectionTitle("Offer Streak")
                        Tile {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(saved, format: .currency(code: "USD")).font(.title.bold()).foregroundStyle(Theme.accent)
                                    Text("saved from \(offers.reduce(0) { $0 + $1.redeemedCount }) redeemed offers")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "flame.fill").font(.largeTitle).foregroundStyle(Theme.gradient)
                            }
                        }
                    }

                    if !byIssuer.isEmpty {
                        VStack(spacing: 10) {
                            SectionTitle("By Issuer")
                            ForEach(byIssuer, id: \.0) { issuer, count, value in
                                Tile {
                                    HStack {
                                        Text(issuer).font(.headline)
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("\(count) offers").font(.subheadline)
                                            Text(value, format: .currency(code: "USD")).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if cards.isEmpty {
                        Tile {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Get started").font(.headline)
                                Text("Open Search to browse every card, then add yours to start tracking offers.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Button("Browse cards") { tab = .search }.buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("For You")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        Tile {
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.title.bold())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func shortcut(_ title: String, _ icon: String, _ target: AppTab) -> some View {
        Button { tab = target } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundStyle(Theme.gradient)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Theme.tile, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(.plain)
    }
}
