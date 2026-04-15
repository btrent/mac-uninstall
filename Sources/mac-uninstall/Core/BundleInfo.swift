import Foundation

struct BundleInfo {
    let bundleIdentifier: String
    let bundleName: String
    let displayName: String?
    let vendorPrefix: String?
    let executableName: String?

    var searchNames: [String] {
        var names = [bundleName.lowercased()]
        if let dn = displayName?.lowercased(), !names.contains(dn) {
            names.append(dn)
        }
        let idComponents = bundleIdentifier.split(separator: ".")
        if let last = idComponents.last {
            let shortName = String(last).lowercased()
            if !names.contains(shortName) {
                names.append(shortName)
            }
        }
        return names
    }

    static func from(appPath: String) throws -> BundleInfo {
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")

        guard FileManager.default.fileExists(atPath: plistPath) else {
            throw UninstallError.noPlistFound(appPath)
        }

        guard let plistData = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw UninstallError.invalidPlist(plistPath)
        }

        guard let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw UninstallError.noBundleIdentifier(plistPath)
        }

        let bundleName = (plist["CFBundleName"] as? String)
            ?? (plist["CFBundleDisplayName"] as? String)
            ?? ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension

        let displayName = plist["CFBundleDisplayName"] as? String
        let executableName = plist["CFBundleExecutable"] as? String

        var vendorPrefix: String? = nil
        let idParts = bundleID.split(separator: ".")
        if idParts.count >= 2 {
            vendorPrefix = idParts[0..<2].joined(separator: ".")
        }

        return BundleInfo(
            bundleIdentifier: bundleID,
            bundleName: bundleName,
            displayName: displayName,
            vendorPrefix: vendorPrefix,
            executableName: executableName
        )
    }
}

enum UninstallError: LocalizedError {
    case noPlistFound(String)
    case invalidPlist(String)
    case noBundleIdentifier(String)
    case notRunningAsRoot
    case appNotFound(String)
    case notAnApp(String)

    var errorDescription: String? {
        switch self {
        case .noPlistFound(let p): return "No Info.plist found at \(p)"
        case .invalidPlist(let p): return "Could not parse Info.plist at \(p)"
        case .noBundleIdentifier(let p): return "No CFBundleIdentifier in \(p)"
        case .notRunningAsRoot: return "mac-uninstall must be run as root (use sudo)"
        case .appNotFound(let p): return "App not found at \(p)"
        case .notAnApp(let p): return "\(p) is not a .app bundle"
        }
    }
}
