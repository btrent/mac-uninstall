import Foundation

struct SearchLocations {
    let bundleInfo: BundleInfo
    let appPath: String

    private let fm = FileManager.default
    private let home = NSHomeDirectory()

    func scanAll() -> [FoundItem] {
        var items: [FoundItem] = []

        items.append(contentsOf: scanAppBundle())
        items.append(contentsOf: scanUserApplicationSupport())
        items.append(contentsOf: scanUserCaches())
        items.append(contentsOf: scanUserPreferences())
        items.append(contentsOf: scanUserLaunchAgents())
        items.append(contentsOf: scanUserSavedState())
        items.append(contentsOf: scanUserHTTPStorages())
        items.append(contentsOf: scanUserWebKit())
        items.append(contentsOf: scanUserLogs())
        items.append(contentsOf: scanUserContainers())
        items.append(contentsOf: scanUserGroupContainers())
        items.append(contentsOf: scanUserApplicationScripts())
        items.append(contentsOf: scanRecentDocuments())
        items.append(contentsOf: scanCloudDocs())
        items.append(contentsOf: scanSystemApplicationSupport())
        items.append(contentsOf: scanSystemLaunchAgents())
        items.append(contentsOf: scanSystemLaunchDaemons())
        items.append(contentsOf: scanSystemPreferences())
        items.append(contentsOf: scanSystemCaches())
        items.append(contentsOf: scanInternetPlugins())
        items.append(contentsOf: scanPrivilegedHelperTools())
        items.append(contentsOf: scanDotfiles())
        items.append(contentsOf: scanTCCEntries())

        // Deduplicate by path
        var seen = Set<String>()
        return items.filter { seen.insert($0.path).inserted }
    }

    private func scanAppBundle() -> [FoundItem] {
        [makeItem(path: appPath, category: .appBundle)]
    }

    private func scanUserApplicationSupport() -> [FoundItem] {
        findMatching(in: "\(home)/Library/Application Support", category: .applicationSupport)
    }

    private func scanUserCaches() -> [FoundItem] {
        let base = "\(home)/Library/Caches"
        var items = findMatching(in: base, category: .caches)
        let sentryCrash = "\(base)/SentryCrash"
        if fm.fileExists(atPath: sentryCrash) {
            items.append(contentsOf: findMatching(in: sentryCrash, category: .caches))
        }
        let nsurlBase = "\(base)/com.apple.nsurlsessiond/Downloads"
        if fm.fileExists(atPath: nsurlBase) {
            items.append(contentsOf: findMatching(in: nsurlBase, category: .caches))
        }
        return items
    }

    private func scanUserPreferences() -> [FoundItem] {
        let base = "\(home)/Library/Preferences"
        var items: [FoundItem] = []

        let directPlist = "\(base)/\(bundleInfo.bundleIdentifier).plist"
        if fm.fileExists(atPath: directPlist) {
            items.append(makeItem(path: directPlist, category: .preferences))
        }

        items.append(contentsOf: findMatchingFiles(in: base, category: .preferences))

        let byHost = "\(base)/ByHost"
        if fm.fileExists(atPath: byHost) {
            items.append(contentsOf: findMatchingFiles(in: byHost, category: .preferences))
        }

        if let vendor = extractVendorName() {
            let vendorDir = "\(base)/\(vendor)"
            if fm.fileExists(atPath: vendorDir) {
                items.append(makeItem(path: vendorDir, category: .preferences))
            }
        }

        return items
    }

    private func scanUserLaunchAgents() -> [FoundItem] {
        findMatchingFiles(in: "\(home)/Library/LaunchAgents", category: .launchAgent)
    }

    private func scanUserSavedState() -> [FoundItem] {
        findMatching(in: "\(home)/Library/Saved Application State", category: .savedState)
    }

    private func scanUserHTTPStorages() -> [FoundItem] {
        let base = "\(home)/Library/HTTPStorages"
        var items = findMatching(in: base, category: .httpStorages)
        let cookiesPath = "\(base)/\(bundleInfo.bundleIdentifier).binarycookies"
        if fm.fileExists(atPath: cookiesPath) {
            items.append(makeItem(path: cookiesPath, category: .httpStorages))
        }
        return items
    }

    private func scanUserWebKit() -> [FoundItem] {
        findMatching(in: "\(home)/Library/WebKit", category: .webKit)
    }

    private func scanUserLogs() -> [FoundItem] {
        let base = "\(home)/Library/Logs"
        var items = findMatching(in: base, category: .logs)
        for name in bundleInfo.searchNames {
            let logFile = "\(base)/\(name).log"
            if fm.fileExists(atPath: logFile) && !items.contains(where: { $0.path == logFile }) {
                items.append(makeItem(path: logFile, category: .logs))
            }
        }
        return items
    }

    private func scanUserContainers() -> [FoundItem] {
        findMatching(in: "\(home)/Library/Containers", category: .containers)
    }

    private func scanUserGroupContainers() -> [FoundItem] {
        findMatching(in: "\(home)/Library/Group Containers", category: .groupContainers)
    }

    private func scanUserApplicationScripts() -> [FoundItem] {
        findMatching(in: "\(home)/Library/Application Scripts", category: .applicationScripts)
    }

    private func scanRecentDocuments() -> [FoundItem] {
        let base = "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments"
        return findMatchingFiles(in: base, category: .recentDocuments)
    }

    private func scanCloudDocs() -> [FoundItem] {
        let base = "\(home)/Library/Application Support/CloudDocs/session/containers"
        guard fm.fileExists(atPath: base) else { return [] }
        return findMatching(in: base, category: .cloudDocs)
    }

    private func scanSystemApplicationSupport() -> [FoundItem] {
        let base = "/Library/Application Support"
        var items: [FoundItem] = []
        if let vendor = extractVendorName() {
            let vendorDir = "\(base)/\(vendor)"
            if fm.fileExists(atPath: vendorDir) {
                items.append(makeItem(path: vendorDir, category: .systemApplicationSupport))
            }
        }
        return items
    }

    private func scanSystemLaunchAgents() -> [FoundItem] {
        findMatchingFiles(in: "/Library/LaunchAgents", category: .launchAgent)
    }

    private func scanSystemLaunchDaemons() -> [FoundItem] {
        findMatchingFiles(in: "/Library/LaunchDaemons", category: .launchDaemon)
    }

    private func scanSystemPreferences() -> [FoundItem] {
        findMatchingFiles(in: "/Library/Preferences", category: .systemPreferences)
    }

    private func scanSystemCaches() -> [FoundItem] {
        findMatching(in: "/Library/Caches", category: .systemCaches)
    }

    private func scanInternetPlugins() -> [FoundItem] {
        let base = "/Library/Internet Plug-Ins"
        guard fm.fileExists(atPath: base), let vendor = extractVendorName() else { return [] }
        var items: [FoundItem] = []
        if let contents = try? fm.contentsOfDirectory(atPath: base) {
            for entry in contents where entry.lowercased().contains(vendor.lowercased()) {
                items.append(makeItem(path: "\(base)/\(entry)", category: .internetPlugins))
            }
        }
        return items
    }

    private func scanPrivilegedHelperTools() -> [FoundItem] {
        findMatchingFiles(in: "/Library/PrivilegedHelperTools", category: .privilegedHelpers)
    }

    private func scanDotfiles() -> [FoundItem] {
        var items: [FoundItem] = []
        for name in bundleInfo.searchNames {
            let dotDir = "\(home)/.\(name)"
            if fm.fileExists(atPath: dotDir) {
                items.append(makeItem(path: dotDir, category: .dotfiles))
            }
            let configDir = "\(home)/.config/\(name)"
            if fm.fileExists(atPath: configDir) {
                items.append(makeItem(path: configDir, category: .dotfiles))
            }
        }
        if bundleInfo.vendorPrefix != nil {
            let configBase = "\(home)/.config"
            if let contents = try? fm.contentsOfDirectory(atPath: configBase) {
                for entry in contents where matchesApp(name: entry) {
                    let fullPath = "\(configBase)/\(entry)"
                    if !items.contains(where: { $0.path == fullPath }) {
                        items.append(makeItem(path: fullPath, category: .dotfiles))
                    }
                }
            }
        }
        return items
    }

    private func scanTCCEntries() -> [FoundItem] {
        let tccPath = "\(home)/Library/Application Support/com.apple.TCC/TCC.db"
        guard fm.fileExists(atPath: tccPath) else { return [] }
        let services = TCCCleaner.findEntries(bundleID: bundleInfo.bundleIdentifier, dbPath: tccPath)
        return services.map { service in
            FoundItem(path: "TCC:\(bundleInfo.bundleIdentifier):\(service)", category: .tccPermissions, sizeBytes: 0, isDirectory: false)
        }
    }

    // MARK: - Helpers

    private func matchesApp(name: String) -> Bool {
        let lower = name.lowercased()
        let bundleID = bundleInfo.bundleIdentifier.lowercased()
        if lower.contains(bundleID) || lower.hasPrefix(bundleID) { return true }
        if bundleID.hasPrefix(lower.replacingOccurrences(of: ".plist", with: "")) { return true }
        for searchName in bundleInfo.searchNames {
            if lower.contains(searchName) { return true }
        }
        return false
    }

    private func findMatching(in directory: String, category: FileCategory) -> [FoundItem] {
        guard fm.fileExists(atPath: directory),
              let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        return contents.filter { matchesApp(name: $0) }.map { makeItem(path: "\(directory)/\($0)", category: category) }
    }

    private func findMatchingFiles(in directory: String, category: FileCategory) -> [FoundItem] {
        guard fm.fileExists(atPath: directory),
              let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        var items: [FoundItem] = []
        for entry in contents where matchesApp(name: entry) {
            let fullPath = "\(directory)/\(entry)"
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)
            if !isDir.boolValue {
                items.append(makeItem(path: fullPath, category: category))
            }
        }
        return items
    }

    private func extractVendorName() -> String? {
        let parts = bundleInfo.bundleIdentifier.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let vendor = String(parts[1])
        return vendor.prefix(1).uppercased() + vendor.dropFirst()
    }

    private func makeItem(path: String, category: FileCategory) -> FoundItem {
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: path, isDirectory: &isDir)
        let size: UInt64? = exists ? calculateSize(path: path, isDirectory: isDir.boolValue) : nil
        return FoundItem(path: path, category: category, sizeBytes: size, isDirectory: isDir.boolValue)
    }

    private func calculateSize(path: String, isDirectory: Bool) -> UInt64 {
        if !isDirectory {
            return (try? fm.attributesOfItem(atPath: path)[.size] as? UInt64) ?? 0
        }
        var total: UInt64 = 0
        if let enumerator = fm.enumerator(atPath: path) {
            while let file = enumerator.nextObject() as? String {
                let fullPath = (path as NSString).appendingPathComponent(file)
                if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? UInt64 {
                    total += size
                }
            }
        }
        return total
    }
}
