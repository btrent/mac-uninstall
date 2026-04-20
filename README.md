# mac-uninstall

Complete macOS application uninstaller -- removes app bundles, caches, preferences, launch agents, privacy permissions, and all other associated files.

## Features

- **Dual interface** -- CLI and SwiftUI GUI modes
- **Automatic process termination** -- kills running application processes before uninstall
- **Comprehensive scanning** -- searches 25+ system locations for app artifacts
- **TCC database cleanup** -- removes accessibility, camera, microphone, and other privacy permissions
- **Launch Services cleanup** -- unregisters app from macOS launch database
- **No external dependencies** -- uses only Foundation, SwiftUI, AppKit, and system SQLite3

mac-uninstall scans and removes files from 25+ location categories that macOS applications scatter across the system:

- **Application bundles** (`.app`)
- **Application Support data** (`~/Library/Application Support/`, `/Library/Application Support/`)
- **Caches** -- both user (`~/Library/Caches/`) and system (`/Library/Caches/`)
- **Preferences** (`~/Library/Preferences/`) and **ByHost preferences** (`~/Library/Preferences/ByHost/`)
- **Launch Agents and Daemons** (`~/Library/LaunchAgents/`, `/Library/LaunchAgents/`, `/Library/LaunchDaemons/`) -- unloads services before removing plist files
- **Saved Application State** (`~/Library/Saved Application State/`)
- **HTTP Storages and cookies** (`~/Library/HTTPStorages/`, `~/Library/Cookies/`)
- **WebKit data** (`~/Library/WebKit/`)
- **Logs** (`~/Library/Logs/`)
- **Containers and Group Containers** (`~/Library/Containers/`, `~/Library/Group Containers/`)
- **Application Scripts** (`~/Library/Application Scripts/`)
- **Recent Documents references**
- **iCloud Documents sync data** (`~/Library/Mobile Documents/`)
- **Internet Plug-Ins** (`~/Library/Internet Plug-Ins/`, `/Library/Internet Plug-Ins/`)
- **Privileged Helper Tools** (`/Library/PrivilegedHelperTools/`)
- **TCC privacy permission entries** -- Screen Recording, Camera, Microphone, Accessibility, Full Disk Access, and more
- **Configuration dotfiles** (`~/.appname`, `~/.config/appname`)
- **System-level Application Support, Preferences, and Caches** (`/Library/`)
- **Launch Services registration**

## Usage

### Building

```bash
swift build -c release
```

### CLI mode

```bash
sudo .build/release/mac-uninstall /Applications/SomeApp.app
```

### CLI with dry-run

Preview what would be removed without deleting anything:

```bash
sudo .build/release/mac-uninstall --dry-run /Applications/SomeApp.app
```

### CLI with auto-confirm

Skip the confirmation prompt and remove everything immediately:

```bash
sudo .build/release/mac-uninstall --yes /Applications/SomeApp.app
```

### GUI mode

Launch the SwiftUI interface by running without arguments:

```bash
sudo .build/release/mac-uninstall
```

**Note:** Must be run as root (`sudo`) to remove system-level files and TCC entries.

## How it works

1. **Reads the app's Info.plist** to extract `CFBundleIdentifier`, display name, and vendor.
2. **Terminates running processes** associated with the application.
3. **Scans 25+ known macOS locations** for files matching the bundle ID, app name, and vendor.
4. **Displays a categorized list** of everything found, with file sizes.
5. **On confirmation:** unloads launch agents/daemons, removes TCC entries, deletes all discovered files, and unregisters the app from Launch Services.
6. **Reports every action taken** with pass/fail status.

## Requirements

- macOS 13+ (Ventura)
- Swift 5.8+

## Project structure

```
mac-uninstall/
  Package.swift
  Sources/
    CSQLite3/
      csqlite3.h
      module.modulemap
    mac-uninstall/
      main.swift                        # Entry point — routes to CLI or GUI
      CLI/
        CLIMode.swift                   # Terminal interface with ANSI color output
      Core/
        AppUninstaller.swift            # Main orchestrator (ObservableObject)
        BundleInfo.swift                # Info.plist parser
        Models.swift                    # FoundItem, ActionTaken, ScanResult types
        SearchLocations.swift           # All 25+ scan location definitions
        TCCCleaner.swift                # SQLite3-based TCC database cleanup
        LaunchServicesCleaner.swift     # launchctl and lsregister wrappers
      GUI/
        GUIApp.swift                    # SwiftUI interface
```

## License

MIT
