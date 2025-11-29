# Repository Guidelines

## Project Structure & Modules
- `Sources/MacSysMonitor/` — SwiftUI/AppKit code: `MacSysMonitorApp.swift` (entry), `SystemMonitor.swift` (metrics), `GraphView.swift`, `MenuBarViews.swift`, `MonitorSettings.swift`.
- `MacSysMonitor/Info.plist` — app metadata (LSUIElement, bundle id).
- `MacSysMonitor.xcodeproj/` — Xcode project; built outputs land in `build/Build/Products/`.
- `scripts/` — tooling (e.g., `make_dmg.sh`).
- `dist/` — packaging artifacts (DMG), `dist/dmg_root/` staging.

## Build, Test, and Development Commands
- Release build:  
  `xcodebuild -project MacSysMonitor.xcodeproj -scheme MacSysMonitor -configuration Release -derivedDataPath build`
- DMG生成:  
  `./scripts/make_dmg.sh` (builds Release, stages app, creates/verifies `dist/MacSysMonitor.dmg`).
- Run in Xcode: open `MacSysMonitor.xcodeproj`, select scheme `MacSysMonitor`, ⌘R.
- Note: target macOS 14.0+. Set signing team in Xcode when running locally.

## Coding Style & Naming
- Swift 5.9+; prefer SwiftUI idioms (struct Views, @StateObject/@ObservedObject).
- Indent with 4 spaces; keep lines concise and self-explanatory names (e.g., `SystemMonitor`, `GraphView`).
- User-visible strings currently Japanese; keep tone consistent.
- No formatter wired; if adding one, document it before enforcing (e.g., SwiftFormat/SwiftLint).

## Testing Guidelines
- No automated tests present. If adding, place under `Tests/` with `XCTestCase` subclasses.
- Name tests after behavior: `testUpdatesSamplesWithinLimit`, etc.
- Run with `xcodebuild test` once a test target exists.

## Commit & Pull Request Guidelines
- Commits: use clear, imperative subjects (e.g., “Add DMG packaging script”, “Fix MenuBarExtra init”). Group related changes.
- PRs should include: summary of changes, build/verification notes (`xcodebuild` or `make_dmg.sh` output), screenshots/GIFs if UI-affecting, and linked issue/ticket if applicable.
- Keep PRs focused (feature/fix per PR) and note any platform/version constraints (macOS 14+).

## Security & Configuration Tips
- LSUIElement hides Dock icon; terminate via Activity Monitor if UI is not reachable.
- Network/CPU stats rely on system calls; no extra entitlements needed. Keep bundle id consistent when distributing.***
