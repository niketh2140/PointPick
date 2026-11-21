import Foundation
import SwiftData

enum SpendCategory: String, CaseIterable, Codable, Identifiable {
    case dining, groceries, gas, travel, transit, online, streaming, drugstores, other
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .dining: "fork.knife"
        case .groceries: "cart.fill"
        case .gas: "fuelpump.fill"
        case .travel: "airplane"
        case .transit: "tram.fill"
        case .online: "bag.fill"
        case .streaming: "play.tv.fill"
        case .drugstores: "cross.case.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    /// Simple keyword lookup so users can search by store name.
    static let storeKeywords: [String: SpendCategory] = [
        "starbucks": .dining, "mcdonald": .dining, "chipotle": .dining, "restaurant": .dining, "doordash": .dining, "uber eats": .dining,
        "whole foods": .groceries, "trader joe": .groceries, "kroger": .groceries, "safeway": .groceries, "costco": .groceries, "walmart": .groceries, "target": .groceries,
        "shell": .gas, "chevron": .gas, "exxon": .gas, "bp": .gas,
        "delta": .travel, "united": .travel, "marriott": .travel, "hilton": .travel, "airbnb": .travel, "expedia": .travel,
        "uber": .transit, "lyft": .transit, "subway": .transit, "metro": .transit,
        "amazon": .online, "ebay": .online, "etsy": .online,
        "netflix": .streaming, "spotify": .streaming, "hulu": .streaming, "disney": .streaming,
        "cvs": .drugstores, "walgreens": .drugstores, "rite aid": .drugstores
    ]

    static func match(store: String) -> SpendCategory? {
        let q = store.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return nil }
        if let c = SpendCategory(rawValue: q) { return c }
        return storeKeywords.first { q.contains($0.key) }?.value
    }
}

enum OfferPeriod: String, Codable, CaseIterable, Identifiable {
    case once, monthly, quarterly, semiannual, annual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .once: "One-time"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .semiannual: "Every 6 months"
        case .annual: "Annual"
        }
    }
    var months: Int {
        switch self {
        case .once: 0
        case .monthly: 1
        case .quarterly: 3
        case .semiannual: 6
        case .annual: 12
        }
    }

    /// End (last instant) of the period that contains `date`, using calendar-aligned periods.
    func periodEnd(containing date: Date, calendar: Calendar = .current) -> Date? {
        guard months > 0 else { return nil }
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else { return nil }
        let startMonth = ((month - 1) / months) * months + 1
        guard let start = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)),
              let next = calendar.date(byAdding: .month, value: months, to: start) else { return nil }
        return next.addingTimeInterval(-1)
    }

    /// End of the current card year (annual credits that follow the card anniversary).
    func anniversaryEnd(containing date: Date, opened: Date, calendar: Calendar = .current) -> Date? {
        let oc = calendar.dateComponents([.month, .day], from: opened)
        let yc = calendar.component(.year, from: date)
        guard var cand = calendar.date(from: DateComponents(year: yc, month: oc.month, day: oc.day)) else { return nil }
        if cand <= date { cand = calendar.date(byAdding: .year, value: 1, to: cand) ?? cand }
        return cand.addingTimeInterval(-1)
    }

    func nextEnd(after end: Date, calendar: Calendar = .current) -> Date? {
        guard months > 0, let nextStart = calendar.date(byAdding: .second, value: 1, to: end),
              let n = calendar.date(byAdding: .month, value: months, to: nextStart) else { return nil }
        return n.addingTimeInterval(-1)
    }
}

struct CatalogCredit: Codable, Hashable {
    var title: String
    var amount: Double
    var period: OfferPeriod
    var note: String
    var needsActivation: Bool = false
    var anniversary: Bool = false      // resets on the card anniversary instead of calendar year
    var ends: String? = nil            // "yyyy-MM-dd" last day the credit is offered

    enum CodingKeys: String, CodingKey { case title, amount, period, note, needsActivation, anniversary, ends }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title); amount = try c.decode(Double.self, forKey: .amount)
        period = try c.decode(OfferPeriod.self, forKey: .period)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        needsActivation = try c.decodeIfPresent(Bool.self, forKey: .needsActivation) ?? false
        anniversary = try c.decodeIfPresent(Bool.self, forKey: .anniversary) ?? false
        ends = try c.decodeIfPresent(String.self, forKey: .ends)
    }
}

/// A card in the bundled catalog (cards.json).
struct CatalogCard: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var issuer: String
    var baseRate: Double          // multiplier for uncategorized spend
    var pointValueCents: Double   // value of one point/mile in cents (1.0 for cashback)
    var annualFee: Double
    var rates: [String: Double]   // SpendCategory.rawValue -> multiplier
    var credits: [CatalogCredit] = []
    var status: String = "unverified"   // verified | partial | unverified
    var source: String? = nil
    var segment: String = "personal"   // personal | business

    enum CodingKeys: String, CodingKey { case id, name, issuer, baseRate, pointValueCents, annualFee, rates, credits, status, source, segment }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        issuer = try c.decode(String.self, forKey: .issuer); baseRate = try c.decode(Double.self, forKey: .baseRate)
        pointValueCents = try c.decode(Double.self, forKey: .pointValueCents); annualFee = try c.decode(Double.self, forKey: .annualFee)
        rates = try c.decode([String: Double].self, forKey: .rates)
        credits = try c.decodeIfPresent([CatalogCredit].self, forKey: .credits) ?? []
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "unverified"
        source = try c.decodeIfPresent(String.self, forKey: .source)
        segment = try c.decodeIfPresent(String.self, forKey: .segment) ?? "personal"
    }
    var topRates: [(SpendCategory, Double)] {
        rates.compactMap { k, v in SpendCategory(rawValue: k).map { ($0, v) } }.filter { $0.1 > baseRate }.sorted { $0.1 > $1.1 }
    }
    var annualCreditValue: Double { credits.reduce(0) { $0 + $1.amount * ($1.period.months == 0 ? 1 : Double(12 / $1.period.months)) } }

}

@Model
final class WalletCard {
    var catalogID: String = ""
    var name: String
    var issuer: String
    var baseRate: Double
    var pointValueCents: Double
    var annualFee: Double
    var rates: [String: Double]
    var addedAt: Date
    var openedDate: Date? = nil
    @Relationship(deleteRule: .cascade, inverse: \Offer.card) var offers: [Offer] = []

    init(catalogID: String = "custom-\(UUID().uuidString)", name: String, issuer: String, baseRate: Double, pointValueCents: Double, annualFee: Double, rates: [String: Double]) {
        self.catalogID = catalogID
        self.name = name; self.issuer = issuer; self.baseRate = baseRate
        self.pointValueCents = pointValueCents; self.annualFee = annualFee
        self.rates = rates; self.addedAt = .now
    }

    /// Creates a wallet card from a catalog card and seeds its trackable offers.
    convenience init(_ c: CatalogCard) {
        self.init(catalogID: c.id, name: c.name, issuer: c.issuer, baseRate: c.baseRate, pointValueCents: c.pointValueCents, annualFee: c.annualFee, rates: c.rates)
        for credit in c.credits {
            let endsOn = credit.ends.flatMap { Offer.parseEnd($0) }
            let o = Offer(title: credit.title, amount: credit.amount, period: credit.period,
                          expiry: Offer.initialExpiry(period: credit.period, anniversary: credit.anniversary, opened: nil, endsOn: endsOn),
                          card: nil)
            o.note = credit.note
            o.needsActivation = credit.needsActivation
            o.anniversary = credit.anniversary
            o.endsOn = endsOn
            offers.append(o)
        }
    }

    /// Recompute anniversary-based offers after the card's open date changes.
    func applyOpenedDate() {
        for o in offers where o.anniversary {
            o.expiry = Offer.initialExpiry(period: o.period, anniversary: true, opened: openedDate, endsOn: o.endsOn)
        }
    }

    func multiplier(for category: SpendCategory) -> Double { rates[category.rawValue] ?? baseRate }
    /// Effective return, in percent of spend.
    func valuePercent(for category: SpendCategory) -> Double { multiplier(for: category) * pointValueCents }

    var availableAmount: Double { offers.filter { !$0.isExpired }.reduce(0) { $0 + $1.remaining } }
    var savedAmount: Double { offers.reduce(0) { $0 + $1.lifetimeSaved } }
}

@Model
final class Offer {
    var title: String
    var note: String = ""
    var amount: Double
    var periodRaw: String = OfferPeriod.once.rawValue
    var expiry: Date?
    var used: Bool
    var usedAt: Date?
    var usedAmount: Double = 0          // used in the current period
    var lifetimeSaved: Double = 0       // across all periods
    var redeemedCount: Int = 0
    var needsActivation: Bool = false
    var activated: Bool = false
    var anniversary: Bool = false
    var endsOn: Date? = nil
    var card: WalletCard?

    init(title: String, amount: Double, period: OfferPeriod = .once, expiry: Date?, card: WalletCard?) {
        self.title = title; self.amount = amount; self.periodRaw = period.rawValue
        self.expiry = expiry; self.used = false; self.card = card
    }

    var period: OfferPeriod { OfferPeriod(rawValue: periodRaw) ?? .once }
    var isExpired: Bool { !used && (expiry.map { $0 < .now } ?? false) }
    var hasEnded: Bool { isExpired && (endsOn.map { $0 < .now } ?? false) }
    var remaining: Double { used ? 0 : max(0, amount - usedAmount) }

    /// Sets how much of this period's credit has been used (0...amount).
    func setUsedAmount(_ v: Double) {
        let clamped = min(max(v, 0), amount)
        lifetimeSaved = max(0, lifetimeSaved + (clamped - usedAmount))
        usedAmount = clamped
        let was = used
        used = clamped >= amount
        if used && !was { redeemedCount += 1; usedAt = .now }
        if !used && was { redeemedCount = max(0, redeemedCount - 1); usedAt = nil }
    }

    func toggleUsed() { setUsedAmount(used ? 0 : amount) }

    /// Recurring credits reset when their period ends, and stop at their end date.
    func rolloverIfNeeded(now: Date = .now) {
        guard period != .once, let start = expiry, start < now else { return }
        if let endsOn, start >= endsOn { return }
        var e = start
        var n = 0
        while e < now, n < 600 {
            guard let nx = period.nextEnd(after: e) else { break }
            e = nx; n += 1
            if let endsOn, e >= endsOn { e = endsOn; break }
        }
        expiry = e
        used = false; usedAmount = 0; usedAt = nil
    }

    static func parseEnd(_ s: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: s).flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0)?.addingTimeInterval(-1) }
    }

    static func initialExpiry(period: OfferPeriod, anniversary: Bool, opened: Date?, endsOn: Date?, now: Date = .now) -> Date? {
        var end: Date?
        if anniversary, period == .annual, let opened { end = period.anniversaryEnd(containing: now, opened: opened) }
        else { end = period.periodEnd(containing: now) }
        if let endsOn, let e = end { return min(e, endsOn) }
        return end ?? endsOn
    }
}
