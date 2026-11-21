# Optional in-app support

The App Store build exposes Settings → About → Support SwiftRust. Enable `SWIFTRUST_APPSTORE` in `SWIFT_ACTIVE_COMPILATION_CONDITIONS` in the external signing copy; preserve inherited conditions. The public project does not enable it by default. This is a build-time distribution choice, not a runtime receipt or review-environment detection workaround. The same interface works in TestFlight and production.

| Product ID | Chinese name | English name | US base price requested |
|---|---|---|---|
| swiftrust.airefactor.me.tip.tier1 | 投喂一颗橘子 | An Orange Boost | USD 2.99 |
| swiftrust.airefactor.me.tip.tier2 | 续一杯灵感 | Creative Refill | USD 9.99 |
| swiftrust.airefactor.me.tip.tier3 | 给 Bug 放个假 | Bug’s Day Off | USD 19.99 |
| swiftrust.airefactor.me.tip.tier4 | 给开发者续航 | Dev Power-Up | USD 29.90 |

All four products are **Consumable**: voluntary, repeatable, no subscription, no paid entitlement or extra functionality. Prices shown in the app come exclusively from `Product.displayPrice`. Unavailable products are disabled rather than showing invented prices. The `.storekit` test configuration is a local USD fixture; it does not create products in App Store Connect or set live prices.

StoreKit 2 verifies transactions on device. Verified transactions for these four IDs are finished; unverified transactions are not acknowledged as successful. A launch listener and unfinished-transaction pass process delayed approvals and interrupted purchases. No custom billing server, purchase ledger, account token or analytics is added. Consumable tips have no restorable entitlement; there is no misleading restore button.

References:
- https://developer.apple.com/app-store/review/guidelines/#in-app-purchase
- https://developer.apple.com/in-app-purchase/
- https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase/

The home information menu also links to optional support, email feedback, rating and the About section of Settings. Configure the public numeric `SwiftRustAppStoreID` Info.plist key for your application. Without it, the rating item is disabled and clearly marked unavailable until release. The review URL uses `action=write-review` for this app only. No review request is made automatically and no arbitrary/upstream app ID is substituted.
