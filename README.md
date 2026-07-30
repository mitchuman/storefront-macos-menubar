# Storefront

A macOS menu bar app for jumping into any Shopify store’s admin panel. Pick a store, open the section you need, and get on with it.

![Storefront panel](screenshot.png)

## Features

- Multi-store rail: search, favorite, and reorder the stores you manage
- Section deep links: Products, Orders, Themes, Settings, and more, with quick actions
- Global hotkey and full keyboard navigation
- CSV import/export for bulk store lists

### CSV format

Header row plus one store per line. Color is hex without `#`.

| Display Name | Domain | Color |
| --- | --- | --- |
| Acme Coffee | acme-coffee.myshopify.com | 1f6f4a |
| Northwind Outfitters | northwind-outfitters.myshopify.com | c07a2c |
| Brightleaf | brightleaf-studio.myshopify.com | 3a6ea8 |

```csv
# stores.csv
Display Name,Domain,Color
Acme Coffee,acme-coffee.myshopify.com,1f6f4a
Northwind Outfitters,northwind-outfitters.myshopify.com,c07a2c
Brightleaf,brightleaf-studio.myshopify.com,3a6ea8
```
## Download

**[Download the latest release](https://github.com/nuotsu/storefront-macos-menubar/releases/latest/download/Storefront.dmg)** (macOS 14+)

Releases are Developer ID–signed and notarized. Drag `Storefront.app` into Applications and open it.

If an older build is blocked: **System Settings → Privacy & Security → Open Anyway**.

## Requirements

- macOS 14.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Building

The `.xcodeproj` is generated, not checked in. After cloning:

```sh
xcodegen generate
open Storefront.xcodeproj
```

Re-run `xcodegen generate` any time `project.yml` changes.

### Signing & release

1. Xcode → Settings → Accounts → **Manage Certificates** → add **Developer ID Application**.
2. Copy `Config/Signing.local.xcconfig.example` → `Config/Signing.local.xcconfig`, set `DEVELOPMENT_TEAM`, then `xcodegen generate`.
3. One-time notarization login (needs an [app-specific password](https://appleid.apple.com)):

```sh
xcrun notarytool store-credentials storefront-notary
# Apple ID, app-specific password, Team ID
```

4. Build Release, then:

```sh
brew install create-dmg
./scripts/release-dmg.sh /path/to/Storefront.app
```

Upload `dist/Storefront.dmg` to GitHub Releases. Skip notarization with `SKIP_NOTARIZE=1`.

## License

[MIT](LICENSE). Developed by [nuotsu](https://nuotsu.dev).
