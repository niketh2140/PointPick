# PointPick

## What

An iOS app for tracking credit card rewards and statement credits, modeled on CardPointers. Browse a master catalog of cards, add the ones you hold, and check off each credit as you use it.

## Why

Credit card credits and earn rates are easy to forget. PointPick keeps a catalog of US cards in-repo, lets you track usage on device (SwiftData), and refreshes the catalog from GitHub so data fixes reach installed apps without a new build.

## Requirements

- Xcode (current stable)
- iOS 17+ simulator or device
- No third-party package dependencies

## How to run

1. Open `PointPick.xcodeproj` in Xcode.
2. Pick an iPhone simulator and press Run.

From the command line:

```sh
xcodebuild -project PointPick.xcodeproj -scheme PointPick \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build
```

Debug builds accept launch arguments:

- `-startTab <forYou|pointers|offers|cards|search>` opens a specific tab.
- `-seedDemo YES` adds two demo cards with some credits marked used.

Taking over the project? Read [PROJECT.md](PROJECT.md) for architecture, reset rules, catalog sync, gotchas and the roadmap.

## Source layout

```text
PointPick/
├── PointPick.xcodeproj
└── PointPick/
    ├── PointPickApp.swift       app entry, tab bar
    ├── Models.swift             catalog types, SwiftData, reset
    ├── CatalogStore.swift       bundled/cached/remote catalog
    ├── cards.json               card catalog
    ├── Theme.swift              colors and shared UI
    └── *View.swift              one file per tab
```

| Tab | File |
| --- | --- |
| For You | `ForYouView.swift` |
| Pointers | `BestCardView.swift` |
| Offers | `OffersView.swift` |
| Cards | `MyCardsView.swift` |
| Search (catalog) | `BrowseView.swift` |

## Features

- **Card catalog:** about 90 US cards from Chase, Amex, Bank of America, Capital One, Bilt, Citi, Barclays, Wells Fargo and Discover, plus American Express business cards. Browse by personal/business and by issuer, with search, sorting and issuer filters.
- **My Cards:** add cards from the catalog or create a custom one. Each card shows its credits, earn rates and stats.
- **Credit tracking:** a checkbox per credit, partial amounts (for example $15 of $35 used) with a progress bar, "needs activation" chips, and end dates.
- **Resets:** monthly, quarterly, semiannual and annual credits reset on calendar boundaries. Anniversary credits reset on the card's open date, which you set per card.
- **Offers tab:** every credit across your cards, with Saved and Available totals.
- **For You:** account summary, expiring soon, offer streak and a breakdown by issuer.
- **Pointers:** pick a spend category or store and see which of your cards earns the most.
- **Remote catalog:** card data is downloaded from this repo, so catalog fixes reach the app without a new build.

## Card catalog

`PointPick/cards.json` is the single source of truth. It is bundled with the app as the offline default and also served from this repo:

```
https://raw.githubusercontent.com/niketh2140/PointPick/main/PointPick/cards.json
```

On launch and on pull-to-refresh, the app downloads that file and caches it. It only uses a download whose `version` is at least that of the copy it already has, so it never moves backwards. The URL can be changed in the app's catalog source screen.

### Format

```json
{
  "version": 5,
  "updated": "2026-11-20",
  "cards": [
    {
      "id": "csr",
      "name": "Sapphire Reserve",
      "issuer": "Chase",
      "segment": "personal",
      "baseRate": 1,
      "pointValueCents": 1.5,
      "annualFee": 795,
      "rates": { "dining": 3 },
      "credits": [
        {
          "title": "Travel credit",
          "amount": 300,
          "period": "annual",
          "anniversary": true,
          "needsActivation": false,
          "ends": "2027-09-30",
          "note": ""
        }
      ],
      "status": "verified",
      "source": "https://..."
    }
  ]
}
```

- `period` is one of `once`, `monthly`, `quarterly`, `semiannual`, `annual`.
- `anniversary` resets the credit on the card's open date instead of Dec 31.
- `needsActivation` shows an activation chip.
- `ends` is an optional last date; after it the credit shows "Ended".
- `status` is `verified` (checked against issuer pages), `partial`, or `unverified`.

### Updating the catalog

1. Edit `PointPick/cards.json`.
2. Bump `version` and `updated`.
3. Commit and push to `main`. Installed apps pick it up on their next refresh.

Currently verified: Sapphire Reserve, Amex Platinum, Amex Gold, Venture X. Partially verified: Sapphire Preferred. The rest are unverified. Rates and credits change often, so check with the issuer.

## Known limitations

- No spending caps (for example Amex Gold's $25k grocery cap).
- Earn rates are flat per category. Portal-only and prepaid-hotel bonuses are not modeled.
- No widget, notifications or sync between devices yet.
- Catalog data is not affiliated with or endorsed by any issuer.
