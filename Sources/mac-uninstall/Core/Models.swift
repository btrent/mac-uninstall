import Foundation

/// Categories of files found during scan
enum FileCategory: String, CaseIterable, CustomStringConvertible {
    case appBundle = "Application Bundle"
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case launchAgent = "Launch Agent"
    case launchDaemon = "Launch Daemon"
    case savedState = "Saved Application State"
    case httpStorages = "HTTP Storages"
    case webKit = "WebKit Data"
    case logs = "Logs"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case applicationScripts = "Application Scripts"
    case recentDocuments = "Recent Documents"
    case cloudDocs = "iCloud Documents"
    case internetPlugins = "Internet Plug-Ins"
    case privilegedHelpers = "Privileged Helper Tools"
    case tccPermissions = "Privacy Permissions (TCC)"
    case dotfiles = "Configuration Dotfiles"
    case systemPreferences = "System Preferences"
    case systemCaches = "System Caches"
    case systemApplicationSupport = "System Application Support"

    var description: String { rawValue }
}

/// A file or directory found during scanning
struct FoundItem: Identifiable {
    let id = UUID()
    let path: String
    let category: FileCategory
    let sizeBytes: UInt64?
    let isDirectory: Bool
    var selected: Bool = true

    var formattedSize: String {
        guard let size = sizeBytes else { return "unknown size" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

/// Action taken (for logging)
enum ActionTaken: CustomStringConvertible {
    case unloadedLaunchAgent(path: String)
    case unloadedLaunchDaemon(path: String)
    case removedFile(path: String, category: FileCategory)
    case removedDirectory(path: String, category: FileCategory, sizeBytes: UInt64?)
    case cleanedTCCEntry(bundleID: String, service: String)
    case unregisteredFromLaunchServices(path: String)
    case failed(path: String, error: String)

    var description: String {
        switch self {
        case .unloadedLaunchAgent(let path): return "Unloaded launch agent: \(path)"
        case .unloadedLaunchDaemon(let path): return "Unloaded launch daemon: \(path)"
        case .removedFile(let path, let cat): return "Removed \(cat): \(path)"
        case .removedDirectory(let path, let cat, let size):
            let sizeStr = size.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? ""
            return "Removed \(cat): \(path)" + (sizeStr.isEmpty ? "" : " (\(sizeStr))")
        case .cleanedTCCEntry(let bid, let svc): return "Removed TCC permission: \(svc) for \(bid)"
        case .unregisteredFromLaunchServices(let path): return "Unregistered from Launch Services: \(path)"
        case .failed(let path, let error): return "FAILED: \(path) — \(error)"
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

/// Overall scan result
struct ScanResult {
    let appPath: String
    let bundleInfo: BundleInfo
    let foundItems: [FoundItem]

    var totalSize: UInt64 {
        foundItems.compactMap(\.sizeBytes).reduce(0, +)
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
}
