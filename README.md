# OrbisX iOS

> Arbejdsnavn. Endeligt brand-navn vælges før App Store-submission.

Native iOS-app (SwiftUI) som henter data fra [OrbisX-værktøjets backend](https://github.com/SergentISAF/OrbisX-morgendagens-vaerktoej). Til marketing/PR/sponsorat-ansvarlige der vil tjekke deres brand on-the-go.

## Build

```bash
xcodegen generate
open OrbisX.xcodeproj
```

Eller via CLI:

```bash
xcodebuild -project OrbisX.xcodeproj -scheme OrbisX -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

## Mapper

```
Sources/OrbisX/
├── App.swift                          # @main entry
├── Network/
│   ├── APIClient.swift                # actor med URLSession, Bearer-JWT
│   └── Models.swift                   # Codable matchende backend
├── Features/
│   ├── Auth/
│   │   ├── AuthStore.swift            # @MainActor, login/signup/logout
│   │   └── LoginView.swift            # SwiftUI form
│   ├── Workspace/
│   │   └── WorkspaceView.swift        # liste over brands + add sheet
│   └── EntityDetail/
│       └── EntityDetailView.swift     # AVE-banner, top historier, top medier
└── Utilities/
    ├── Keychain.swift                 # JWT-storage
    └── Color+Hex.swift                # init?(hex:) helper
```

## V1 funktionalitet

- [x] Login / signup mod backend
- [x] Workspace med entities + add/sync
- [x] Entity-detalje med AVE, top historier, top medier
- [x] Share-sheet til rapport-tekst
- [ ] Push-notifikationer (kommer i V2)
- [ ] Hjemmeskærms-widget (kommer i V2)

## Backend

Default: `https://elpris-dashboard.tail330027.ts.net` (skiftes til `app.holmstadit.dk` når DNS er flyttet). Ændres i `APIClient.swift`.

## Status

Bootstrap'et 2026-05-19. Build succeeds, klar til simulator-test og TestFlight-distribution.
