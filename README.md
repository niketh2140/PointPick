# pointpick-catalog

Credit card catalog (`cards.json`) for the PointPick app.

Format: `{ "version": int, "updated": "YYYY-MM-DD", "cards": [ ... ] }`.
Bump `version` on every change; the app only uses a download whose version is at least that of its bundled copy.

Each card has a `status` (`verified` | `partial` | `unverified`) and an optional `source` URL.
Rates and credits are approximate and change often — verify with the issuer.
