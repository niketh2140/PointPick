import SwiftUI
import SwiftData

@main
struct PointPickApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: [WalletCard.self, Offer.self])
    }
}

enum AppTab: Hashable { case forYou, pointers, offers, cards, search }

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var tab: AppTab = {
        switch UserDefaults.standard.string(forKey: "startTab") {
        case "search": .search
        case "cards": .cards
        case "offers": .offers
        case "pointers": .pointers
        default: .forYou
        }
    }()
    var body: some View {
        TabView(selection: $tab) {
            ForYouView(tab: $tab).tag(AppTab.forYou).tabItem { Label("For You", systemImage: "person.crop.circle.fill") }
            BestCardView().tag(AppTab.pointers).tabItem { Label("Pointers", systemImage: "lightbulb.fill") }
            OffersView().tag(AppTab.offers).tabItem { Label("Offers", systemImage: "dollarsign.circle.fill") }
            MyCardsView().tag(AppTab.cards).tabItem { Label("Cards", systemImage: "creditcard.fill") }
            BrowseView().tag(AppTab.search).tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        #if DEBUG
        .task {
            // Launch with `-seedDemo YES` to preload a card (screenshots/testing only).
            guard UserDefaults.standard.bool(forKey: "seedDemo"),
                  (try? context.fetchCount(FetchDescriptor<WalletCard>())) == 0 else { return }
            for id in ["csr", "amexgold"] {
                if let c = CatalogStore.shared.cards.first(where: { $0.id == id }) { context.insert(WalletCard(c)) }
            }
            if let o = (try? context.fetch(FetchDescriptor<Offer>()))?.first(where: { $0.title.hasPrefix("Dunkin") }) { o.setUsedAmount(o.amount) }
            if let o = (try? context.fetch(FetchDescriptor<Offer>()))?.first(where: { $0.title.hasPrefix("DoorDash") }) { o.setUsedAmount(15) }
        }
        #endif
    }
}
