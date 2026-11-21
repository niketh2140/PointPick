# PointPick: project handover

Everything a new developer needs to take this over. For a short intro, see `README.md`.

## 1. What this is

An iOS app (SwiftUI + SwiftData, iOS 17+) modeled on CardPointers. A master catalog of US credit cards is the base of the app. Users add cards to **My Cards** and track each credit or offer: used or unused checkbox, partial amounts, activation, resets and end dates.

Scope decisions made so far:
- Personal cards: Chase, American Express, Bank of America, Capital One, Bilt, Citi, Barclays, Wells Fargo, Discover.
- Business cards: American Express only.
- UI should follow the original app's patterns as closely as practical (tab bar, grouped lists, checkbox credits).
- The catalog is hosted in this repo and downloaded by the app, so data fixes don't need an app release.

## 2. Repository layout

```
PointPick/                      repo root
├── README.md                   user-facing intro
├── PROJECT.md                  this file
├── PointPick.xcodeproj         Xcode project
└── PointPick/                  app source (file-system synchronized group: new files here are picked up automatically)
    ├── PointPickApp.swift      @main, tab bar, launch tasks, wallet sync, rollover, DEBUG seed
    ├── Models.swift            catalog structs, SwiftData models, reset logic
    ├── CatalogStore.swift      catalog loading, caching, remote refresh
    ├── cards.json              the catalog (bundled AND served from GitHub)
    ├── Theme.swift             colors, gradient, list styling, small shared views
    ├── ForYouView.swift        dashboard
    ├── BestCardView.swift      "Pointers" tab
    ├── OffersView.swift        all credits across cards, AddOfferView
    ├── MyCardsView.swift       card list, card detail, OfferRow, UsageSheet, CustomCardView
    └── BrowseView.swift        "Search" tab: catalog browser, detail, catalog source screen
```

## 3. Build and run

Requirements: Xcode with an iOS 17+ simulator. There are no third-party dependencies.

```sh
# list simulators, pick an id
xcrun simctl list devices available

xcodebuild -project PointPick.xcodeproj -scheme PointPick \
  -destination 'id=<SIMULATOR_ID>' -derivedDataPath build build

xcrun simctl boot <SIMULATOR_ID>            # if not already booted
xcrun simctl install <SIMULATOR_ID> build/Build/Products/Debug-iphonesimulator/PointPick.app
xcrun simctl launch <SIMULATOR_ID> com.example.PointPick -startTab cards
```

Debug-only launch arguments:
- `-startTab forYou|pointers|offers|cards|search`
- `-seedDemo YES` adds Sapphire Reserve and Amex Gold, marks one credit used and one partly used (only when the wallet is empty).

Notes and gotchas:
- The Xcode project was originally hand-written and later rewritten by Xcode. The project-level Debug configuration needs `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"`, or the `#if DEBUG` seed code is compiled out. It is set now; don't remove it.
- Running on a physical iPhone needs a signing team set in Xcode. The bundle id is a placeholder (`com.example.PointPick`). Builds signed with a free Apple ID expire after 7 days.
- The Swift language mode is 5.0.
- There is no test target. Reset logic was checked once with a throwaway script that compiled `Models.swift` with a small `main.swift` using `swiftc` on macOS. Adding a real XCTest target is a good next step.

## 4. Architecture

### 4.1 Data flow

```
GitHub raw URL ──download──▶ catalog-cache.json (Application Support)
bundled cards.json ─────────┐            │
                            ▼            ▼
                         CatalogStore (newest version wins, never downgrades)
                            │
              Search tab ◀──┤──▶ syncWallet() ──▶ WalletCard / Offer (SwiftData)
```

- `CatalogStore` (an `@Observable` singleton) loads the cached copy if its version is at least the bundled version, otherwise the bundled copy.
- `refresh()` runs at launch (in `RootView`) and on pull-to-refresh in Search. It ignores files with a lower `version`, and writes valid downloads to the cache.
- Decoding is lossy: a malformed card is skipped and reported in `lastError` instead of failing the whole file.
- The default URL can be overridden in the app (Search tab, filter menu, "Catalog source"). It supports `https` and `file` URLs, which is handy for testing a draft catalog.

### 4.2 Models (`Models.swift`)

- `CatalogCard` and `CatalogCredit` are read-only value types decoded from JSON.
- `WalletCard` (`@Model`) is a card the user owns. It holds a **copy** of the catalog fields (so user data stays readable even if the catalog changes), plus `catalogID`, `openedDate` and `offers` (cascade delete).
- `Offer` (`@Model`) is one trackable credit.
  - Usage fields: `used`, `usedAmount` (current period), `lifetimeSaved`, `redeemedCount`, `usedAt`, `lastUsedAt`.
  - Schedule fields: `period`, `expiry` (end of the current period), `anniversary`, `endsOn`.
  - `fromCatalog` is true for credits created from the catalog. Only those are changed by catalog updates; offers the user adds by hand are never touched.
  - `needsActivation` and `activated` drive the activation chip.
- All stored properties have defaults so SwiftData can do lightweight migrations when fields are added. Keep it that way.

### 4.3 Reset logic

- Periods: `once`, `monthly`, `quarterly`, `semiannual`, `annual`. Calendar-aligned (a quarter ends Mar 31, Jun 30, Sep 30, Dec 31).
- Anniversary credits (`anniversary: true`, annual) reset on the card's open date once `openedDate` is set. Without it they fall back to Dec 31, and the card page shows a reminder. A Feb 29 open date resolves to Feb 28 in non-leap years.
- `Offer.rolloverIfNeeded()` advances `expiry` when a period has passed and clears current-period usage. It stops at `endsOn`; after that the credit shows "Ended". `RootView` runs it for all offers at launch and when the app becomes active.
- `WalletCard.applyOpenedDate()` recomputes anniversary expiries when the open date changes. Usage is kept only if it happened inside the new card year (`lastUsedAt`).
- `Offer.setUsedAmount(_:)` is the single place that updates usage. It keeps `used`, `usedAmount`, `lifetimeSaved` and `redeemedCount` consistent. `toggleUsed()` and the usage sheet both call it.

### 4.4 Catalog sync into owned cards

`WalletCard.sync(with:)` runs from `RootView.syncWallet()` at launch and whenever `CatalogStore.version` changes.
- Updates name, issuer, fee, rates and point value.
- Matches credits by title among `fromCatalog` offers. Matches are updated, keeping usage. New catalog credits are inserted.
- Credits dropped from the catalog are deleted if never used; otherwise they get an end date so they run out.
- Renaming a credit's `title` in `cards.json` therefore looks like "old removed, new added". Avoid renaming; change `note` or `amount` instead.

### 4.5 Screens

| Tab | View | Notes |
| --- | --- | --- |
| For You | `ForYouView` | Account summary, shortcuts, expiring soon, offer streak, by issuer. |
| Pointers | `BestCardView` | Pick a category chip or type a store; ranks your cards by effective return (`multiplier × pointValueCents`). Store lookup uses a small keyword table in `SpendCategory.storeKeywords`. |
| Offers | `OffersView` | All credits grouped by card, Saved and Available totals, add custom offer. |
| Cards | `MyCardsView` | Owned cards. Detail page: stats, offers, card anniversary, earn rates, remove. |
| Search | `BrowseView` | Catalog by Personal/Business and issuer, search, sort, add button, catalog source settings. |

## 5. The card catalog

Format and update steps are in `README.md`. Extra details for maintainers:

- `status`: `verified` (checked against issuer pages), `partial`, `unverified`. The UI shows badges for this.
- Currently verified: Sapphire Reserve, Amex Platinum, Amex Gold, Venture X. Partial: Sapphire Preferred. The other 86 cards are unverified and may be out of date (annual fees and credits change often).
- Verification method used so far: official issuer product pages first, aggregator blogs only to find leads. Where sources conflicted, the unconfirmed credit was left out rather than guessed. Left out for that reason: Oura, Equinox, the Global Entry credit amount, a one-time $250 hotel credit expiring Dec 31, 2026, and Apple subscription credits.
- Credits valued in points or miles (such as the Venture X 10,000-mile anniversary bonus) are entered as an approximate dollar amount, with the basis in `note`.
- Always bump `version` and `updated` on any change, or installed apps will not apply it.

## 6. Known limitations

- No spending caps (for example the Amex Gold $25,000 grocery cap).
- Earn rates are flat per category. Portal-only and special bonuses are not modeled (Venture X 10x/5x on Capital One Travel, Amex Gold prepaid hotels, rotating 5% categories).
- No notifications, widget, sign-up bonus tracking, fee-date reminders, or points balances.
- Data is stored only on the device (SwiftData). No iCloud sync, export or import. Deleting the app deletes the data.
- Amounts are USD only. The app is dark mode only by design.
- No automated tests.

## 7. Suggested roadmap

1. Verify more cards from official sources, starting with cards the owner holds.
2. Local notifications: credits expiring, unactivated credits, annual fee date.
3. Export/import of wallet data, then iCloud sync.
4. Unit tests for `OfferPeriod`, `Offer` and `WalletCard.sync`.
5. Spend caps and special-rate rules in the catalog format.
6. Widget showing available credits and what expires soon.
7. Sign-up bonus tracker (spend target and deadline).

## 8. Conventions

- Keep user data separate from catalog data; never overwrite usage fields from the catalog.
- Put reset and usage rules in `Models.swift`, not in views.
- Commit catalog edits and app changes in the same repo; the raw GitHub URL always serves the `main` branch.
- Card data is not affiliated with or endorsed by any issuer. Check issuer pages before relying on amounts.

## 9. Accounts and hosting

- Source and catalog host: the public GitHub repo `niketh2140/PointPick`, branch `main`.
- Catalog URL: `https://raw.githubusercontent.com/niketh2140/PointPick/main/PointPick/cards.json`. GitHub's raw CDN can serve a stale copy for a few minutes after a push.
- No backend, analytics, or API keys are used anywhere.
