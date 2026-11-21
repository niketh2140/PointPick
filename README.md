# PointPick

iOS app (SwiftUI + SwiftData) for tracking credit card offers and credits.

- `PointPick/` – app source. `PointPick/cards.json` is the card catalog: it is bundled as the offline default and also served from this repo's raw URL, so a push updates installed apps.
- `PointPick.xcodeproj` – Xcode project.

Catalog format: `{ "version": int, "updated": "YYYY-MM-DD", "cards": [ ... ] }`.
Bump `version` on every change; the app only uses a download whose version is at least that of its bundled copy.
Each card has a `status` (`verified` | `partial` | `unverified`) and an optional `source` URL.
Rates and credits are approximate and change often — verify with the issuer.
