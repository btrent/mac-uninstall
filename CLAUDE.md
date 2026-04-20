# mac-uninstall

## Project Overview
macOS application uninstaller written in Swift. Offers both CLI and SwiftUI GUI modes. Must be run as root (sudo).

## Build & Run
- Build: `swift build` (debug) or `swift build -c release`
- Run CLI: `sudo .build/release/mac-uninstall /Applications/SomeApp.app`
- Run GUI: `sudo .build/release/mac-uninstall`
- The project uses Swift 5.8 and targets macOS 13+

## Architecture
- `Sources/mac-uninstall/Core/` -- Shared engine used by both CLI and GUI
  - `AppUninstaller.swift` -- Main orchestrator (ObservableObject)
  - `BundleInfo.swift` -- Info.plist parser
  - `SearchLocations.swift` -- All 25+ scan locations
  - `Models.swift` -- FoundItem, ActionTaken, ScanResult types
  - `TCCCleaner.swift` -- SQLite3-based TCC database cleanup
  - `LaunchServicesCleaner.swift` -- launchctl and lsregister wrappers
  - `ProcessTerminator.swift` -- Process discovery and termination (NSWorkspace + pgrep/ps)
- `Sources/mac-uninstall/CLI/CLIMode.swift` -- Terminal interface
- `Sources/mac-uninstall/GUI/GUIApp.swift` -- SwiftUI interface
- `Sources/mac-uninstall/main.swift` -- Entry point routing
- `Sources/CSQLite3/` -- System library module map for sqlite3

## Key Design Decisions
- No external dependencies -- uses only Foundation, SwiftUI, AppKit, and system SQLite3
- Bundle ID is the primary search key, supplemented by app name and vendor prefix
- Launch agents/daemons are always unloaded BEFORE their plist files are deleted
- TCC database is modified directly via SQLite3 (not tccutil) for per-app precision
- Scan results are deduplicated by path to prevent double-deletion
- GUI uses NSApplication programmatically (no @main) since main.swift handles routing
- Running processes are terminated BEFORE any file deletion (Step 0 in uninstall)
- Process termination uses graceful shutdown first (SIGTERM/terminate), then force kill (SIGKILL) after 3 seconds
- Skips terminating the uninstaller's own process

## Conventions
- All search locations are defined in SearchLocations.swift -- add new locations there
- File categories are defined in the FileCategory enum in Models.swift
- ANSI color output helpers are in CLIMode.swift (private functions)
