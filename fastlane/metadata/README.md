# App Store Localization Metadata

Generated from the App Store Connect localization pass for NumPad 1.7.2.

- `fastlane/metadata/<locale>/` contains app/version metadata: name, subtitle, promotional text, release notes, keywords, and description.
- `fastlane/iap_metadata/<product-id>/<locale>/` contains localized in-app purchase names and descriptions for `numpad.pro.lifetime` and `numpad.pack.finance`.
- These files cover the 39 remaining localizations not already entered manually in App Store Connect during the first pass.
- Locale directories use fastlane's documented App Store language codes, including regional suffixes such as `bn-BD`, `gu-IN`, `ta-IN`, `te-IN`, `sl-SI`, and `ur-PK`.
- Run `fastlane ios upload_metadata` after configuring App Store Connect API credentials to upload the app/version metadata only. The separate `fastlane/iap_metadata` tree is staged for App Store Connect UI/API upload of the two in-app purchases.

Direct browser entry for these locales was blocked by the Chrome automation virtual clipboard not being installed and macOS denying scripted keystrokes, so this directory is the upload-ready source of truth once App Store Connect API/fastlane credentials or a working paste bridge are available.
