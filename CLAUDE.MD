# CLAUDE.MD - Sabique Project Guide

## Project Overview

Sabique is an iOS music playlist management app built with **SwiftUI** and **MusicKit**. It integrates with Apple Music to let users create playlists, set song highlight (chorus/サビ) sections, and play them back sequentially. The app also features a community platform (Firebase-backed) for sharing playlists, and a freemium monetization model via StoreKit 2.

- **Language:** Swift
- **Platform:** iOS (Xcode project, no SPM Package.swift — dependencies managed via Xcode SPM integration)
- **Bundle ID:** `com.yuki.Sabique`
- **Author:** 高木祐輝 (Takagi Yuki)
- **Architecture:** MVVM (Model-View-ViewModel)

## Repository Structure

```
sabique/
├── CLAUDE.MD                          # This file — project guide for AI assistants
├── README.md                          # Minimal readme
├── Sabique/                           # Main application source
│   ├── SabiqueApp.swift               # @main entry point, sets up environment
│   ├── ContentView.swift              # Legacy/unused view
│   ├── Models/                        # Data layer
│   │   ├── Playlist.swift             # @Model — local playlist (SwiftData)
│   │   ├── TrackInPlaylist.swift      # @Model — track in playlist (SwiftData)
│   │   ├── CommunityPlaylist.swift    # Codable — Firestore community playlist
│   │   ├── UserProfile.swift          # Codable — Firestore user profile
│   │   ├── PlaylistReport.swift       # Codable — content report model
│   │   ├── PurchaseState.swift        # FreeTierLimits enum (free tier constants)
│   │   └── SchemaVersioning.swift     # SwiftData migration plan (v1 only currently)
│   ├── Services/                      # Business logic layer
│   │   ├── ChorusPlayerManager.swift  # Music playback & highlight control
│   │   ├── StoreManager.swift         # In-app purchase management (StoreKit 2)
│   │   ├── AuthManager.swift          # Sign in with Apple + Firebase Auth
│   │   ├── CommunityManager.swift     # Firestore CRUD for community features
│   │   ├── PlaylistImporter.swift     # Import from .sabique JSON files
│   │   ├── PlaylistExporter.swift     # Export to .sabique JSON files
│   │   ├── PlaylistValidator.swift    # NG word filtering & name validation
│   │   ├── LikeManager.swift          # Like state management (UserDefaults)
│   │   └── BlockManager.swift         # User blocking (UserDefaults, singleton)
│   ├── Views/                         # UI layer (SwiftUI)
│   │   ├── MainTabView.swift          # Root tab navigation (3 tabs)
│   │   ├── PlaylistListView.swift     # "My Playlists" tab
│   │   ├── PlaylistDetailView.swift   # Playlist detail & track list
│   │   ├── ChorusEditView.swift       # Highlight start/end time editor
│   │   ├── SongSearchView.swift       # Apple Music catalog search
│   │   ├── AppleMusicPlaylistImportView.swift  # Import from Apple Music library
│   │   ├── ArtworkPickerView.swift    # Album art selector
│   │   ├── CommunityView.swift        # Community browse tab (popular/newest)
│   │   ├── CommunityPlaylistDetailView.swift   # View shared playlist details
│   │   ├── PublishPlaylistView.swift   # Publish playlist to community
│   │   ├── ProfileView.swift          # User profile tab
│   │   ├── SettingsView.swift         # Account settings
│   │   ├── PaywallView.swift          # Premium upsell screen
│   │   ├── ReportPlaylistView.swift   # Content moderation / report
│   │   └── SignInTestView.swift       # Dev/test sign-in screen
│   ├── Assets.xcassets/               # Images, icons, colors, app icon
│   ├── Localizable.xcstrings          # Multi-language strings (Japanese primary)
│   ├── GoogleService-Info.plist       # Firebase configuration
│   └── Sabique.entitlements           # Sign in with Apple capability
├── Sabique.xcodeproj/                 # Xcode project configuration
├── SabiqueTests/                      # Unit tests (Swift Testing framework)
│   └── SabiqueTests.swift             # Scaffold — minimal coverage
└── SabiqueUITests/                    # UI tests (XCTest framework)
    ├── SabiqueUITests.swift           # Launch + basic UI test scaffold
    └── SabiqueUITestsLaunchTests.swift
```

## Key Technologies & Frameworks

| Framework | Purpose |
|---|---|
| **SwiftUI** | Declarative UI |
| **SwiftData** | Local data persistence (Playlist, TrackInPlaylist) |
| **MusicKit** | Apple Music search, playback, catalog access |
| **Combine** | Reactive state with `@Published` / `ObservableObject` |
| **StoreKit 2** | In-app purchases (premium tier) |
| **Firebase Auth** | Authentication (Sign in with Apple backend) |
| **Firebase Firestore** | Cloud database for community playlists, profiles, reports |
| **Firebase Storage** | File storage |
| **AuthenticationServices** | Sign in with Apple UI flow |
| **CryptoKit** | SHA256 nonce for PKCE auth flow |
| **AVKit** | Audio/video playback APIs |

## Architecture & Design Patterns

### MVVM with EnvironmentObject Injection

The app follows MVVM. Four `@StateObject` managers are created at the app root (`SabiqueApp.swift`) and injected via `.environmentObject()`:

- **`ChorusPlayerManager`** — Playback state, sequential highlight playback, timer-based track transitions
- **`StoreManager`** — Premium purchase state, StoreKit 2 transaction listening
- **`AuthManager`** — Apple Sign In, Firebase Auth session, user profile creation
- **`CommunityManager`** — Firestore operations (publish, fetch, like, download, search)

### Key Patterns

- **`@MainActor`** on managers for thread safety
- **`async/await`** throughout services and views
- **`@Query`** for reactive SwiftData fetches
- **`@AppStorage`** for UserDefaults-backed preferences
- **Singleton pattern** for `BlockManager` and `LikeManager`
- **Timer-based polling** (0.1s interval) in `ChorusPlayerManager` for playback position monitoring

## Data Models

### Local (SwiftData)

**Playlist** — `@Model`
- `id: UUID`, `name: String` (3–50 chars), `createdAt: Date`, `orderIndex: Int`
- `tracks: [TrackInPlaylist]` — cascade delete relationship

**TrackInPlaylist** — `@Model`
- `id: UUID`, `appleMusicSongId: String`, `title: String`, `artist: String`
- `chorusStartSeconds: Double?`, `chorusEndSeconds: Double?` — highlight range
- `artworkURL: URL?`, `orderIndex: Int`, `isLocked: Bool`
- `playlist: Playlist?` — inverse relationship

**Schema versioning** is set up via `SchemaVersioning.swift` with `SabiqueMigrationPlan`. Currently at v1 only.

### Cloud (Firestore)

**CommunityPlaylist** — `communityPlaylists` collection
- Tracks, author info (snapshot at publish time), like/download/view counts

**UserProfile** — `users` collection
- Nickname (max 10 chars), country code, profile artwork, premium status, ban status
- Nickname/country change cooldowns (30 days after 2nd change)

**PlaylistReport** — `reports` collection
- Report reason, reporter/reported IDs

## Freemium Model (FreeTierLimits)

Defined in `PurchaseState.swift`:

| Limit | Free | Premium |
|---|---|---|
| Max playlists | 2 | Unlimited |
| Tracks per playlist | 3 | Unlimited |
| Community publish min tracks | 3 | 3 |
| Community publish max tracks | — | 100 |
| Monthly publish limit | 3 | 10 |

Product ID: `com.yukitakagi.sabique.premium`

## Core Features

### Highlight (Chorus) Playback
- Users set `chorusStartSeconds` / `chorusEndSeconds` per track
- `ChorusPlayerManager` uses `ApplicationMusicPlayer` to seek to start, auto-advance at end
- Timer-based control (0.1s intervals), `isTransitioning` flag prevents double-skip

### Community (Firebase)
- Publish/unpublish playlists to Firestore
- Browse popular (by likes) and newest playlists
- Like, download (import), view count tracking
- Client-side search filtering
- NG word filtering from Firestore `config/ngWords` document with local fallback list

### Authentication
- Sign in with Apple → Firebase Auth
- PKCE flow with nonce (CryptoKit SHA256)
- Auto-creates `UserProfile` on first sign-in
- Account deletion support (Apple requirement)

### Data Export/Import
- `.sabique` JSON file format
- ISRC code matching for cross-region track resolution
- Fallback to Apple Music song ID verification

## Firebase Security Rules

```javascript
match /communityPlaylists/{playlistId} {
  allow read: if true;
  allow create: if request.auth != null;
  allow update, delete: if request.auth != null
                        && request.auth.uid == resource.data.authorId;
}
```

## UI Conventions

- **Forced dark mode**: `.preferredColorScheme(.dark)` on root view
- **Tab navigation**: 3 tabs — My Playlists, Community, Profile
- **Community tabs**: PageStyle TabView (horizontal swipe between popular/newest)
- **Custom backgrounds**: Blurred random track artwork with 0.5s fade
- **Drag & drop**: Playlist and track reordering
- **Swipe to delete**: Track removal
- **Localization**: Japanese primary, via `Localizable.xcstrings` using `String(localized:)`

## App Entry Point

`SabiqueApp.swift` (`@main`):
1. Configures Firebase (`FirebaseApp.configure()`)
2. Creates `ModelContainer` with `SchemaV1` models and `SabiqueMigrationPlan`
3. Injects all four managers as `@EnvironmentObject`
4. Presents `MainTabView` as root

## Testing

| Target | Framework | Status |
|---|---|---|
| `SabiqueTests` | Swift Testing (`import Testing`) | Scaffold only — template test |
| `SabiqueUITests` | XCTest (`XCUIApplication`) | Scaffold — launch + performance test |

Tests are minimal. There is no CI/CD pipeline configured.

## Build & Run

- **IDE:** Xcode (required — this is a native .xcodeproj, not an SPM package)
- **Targets:** `Sabique` (app), `SabiqueTests`, `SabiqueUITests`
- **Configurations:** Debug / Release
- **Capabilities:** Sign in with Apple (entitlements)
- **No command-line build scripts** — use `xcodebuild` or Xcode GUI

```bash
# Build from command line (if Xcode CLI tools installed)
xcodebuild -project Sabique.xcodeproj -scheme Sabique -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -project Sabique.xcodeproj -scheme Sabique -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Development Conventions

### Code Style
- Swift source files use `//` header comments with file name and purpose
- Japanese inline comments are common (this is a Japanese-authored project)
- `// MARK: -` sections for code organization
- `@MainActor` on all ObservableObject managers
- Async methods use `async throws` pattern with do/catch

### File Organization
- **Models/** — Pure data definitions (SwiftData `@Model` or `Codable` structs)
- **Services/** — Business logic, no UI imports. Managers are `ObservableObject` classes
- **Views/** — SwiftUI views. Large views (600–1100+ lines) with inline logic

### Naming Conventions
- Views: `*View.swift` (e.g., `PlaylistDetailView.swift`)
- Managers/Services: `*Manager.swift` (e.g., `StoreManager.swift`)
- Models: Named by entity (e.g., `Playlist.swift`, `UserProfile.swift`)
- Validation: `*Validator.swift`
- Import/Export: `Playlist{Importer,Exporter}.swift`

### State Management
- `@StateObject` for manager creation (only in `SabiqueApp`)
- `@EnvironmentObject` for manager access in views
- `@Query` for SwiftData model queries
- `@AppStorage` for simple UserDefaults values
- `@State` / `@Binding` for local view state

### Error Handling
- Custom error enums conforming to `LocalizedError`
- Try-catch with fallback mechanisms (e.g., NG words fallback list)
- Console logging with emoji prefixes (`✅`, `⚠️`, `❌`)

### Commit Style
- Short messages, typically describing what was changed (e.g., `bug fixed`, `ver2.0 updated`)
- No conventional commit format enforced

## Important Considerations for AI Assistants

1. **This is an Xcode project** — there is no `Package.swift`, `package.json`, or `Makefile`. Building requires Xcode or `xcodebuild`.
2. **Primary language is Japanese** — comments, UI strings, NG word lists, and documentation are predominantly in Japanese.
3. **No .gitignore file** — be careful not to commit sensitive files or build artifacts.
4. **`GoogleService-Info.plist` is committed** — contains Firebase API keys (standard practice for client-side Firebase, but worth noting).
5. **`ContentView.swift` is legacy** — unused, the actual root is `MainTabView` via `SabiqueApp`.
6. **SwiftData migration** — when modifying models, update `SchemaVersioning.swift` with a new schema version and migration stage.
7. **Free tier limits** are constants in `PurchaseState.swift` (`FreeTierLimits` enum) — check these when modifying playlist/track creation logic.
8. **Community features require Firebase** — testing community-related code needs a Firebase backend connection.
9. **MusicKit requires authorization** — `MusicAuthorization.request()` must be called before Apple Music API access.
10. **Test coverage is minimal** — adding tests for new features is recommended but not enforced by CI.

## Future Expansion Ideas

- Waveform visualization for highlight editing
- Offline playback support
- iOS Widget integration
- Community feature expansion (follow, comments)
