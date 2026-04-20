import Foundation

class AppUninstaller {
    let appPath: String
    private(set) var bundleInfo: BundleInfo?
    private(set) var scanResult: ScanResult?
    private(set) var actions: [ActionTaken] = []

    var onAction: ((ActionTaken) -> Void)?

    init(appPath: String) {
        self.appPath = (appPath as NSString).standardizingPath
    }

    func validate() throws {
        guard getuid() == 0 else {
            throw UninstallError.notRunningAsRoot
        }
        let fm = FileManager.default
        guard fm.fileExists(atPath: appPath) else {
            throw UninstallError.appNotFound(appPath)
        }
        guard appPath.hasSuffix(".app") else {
            throw UninstallError.notAnApp(appPath)
        }
    }

    func scan() throws -> ScanResult {
        let info = try BundleInfo.from(appPath: appPath)
        self.bundleInfo = info
        let locations = SearchLocations(bundleInfo: info, appPath: appPath)
        let items = locations.scanAll()

        // Discover running processes
        let matchedProcesses = ProcessTerminator.findProcesses(bundleInfo: info, appPath: appPath)
        let runningProcesses = matchedProcesses.map { proc in
            RunningProcess(pid: proc.pid, name: proc.name, path: proc.path, bundleIdentifier: proc.bundleIdentifier)
        }

        let result = ScanResult(appPath: appPath, bundleInfo: info, foundItems: items, runningProcesses: runningProcesses)
        self.scanResult = result
        return result
    }

    func execute(items: [FoundItem]) -> [ActionTaken] {
        guard let info = bundleInfo else { return [] }
        actions = []
        let fm = FileManager.default

        // Step 0: Terminate running processes FIRST
        let processes = ProcessTerminator.findProcesses(bundleInfo: info, appPath: appPath)
        if !processes.isEmpty {
            let results = ProcessTerminator.terminate(processes: processes)
            for result in results {
                switch result {
                case .terminated(let pid, let name, let graceful):
                    record(.terminatedProcess(pid: pid, name: name, graceful: graceful))
                case .failed(let pid, let name, let error):
                    record(.terminatedProcessFailed(pid: pid, name: name, error: error))
                case .skipped:
                    break
                }
            }
        }

        // Step 1: Unload launch agents and daemons FIRST
        let launchItems = items.filter { $0.category == .launchAgent || $0.category == .launchDaemon }
        for item in launchItems {
            let isDaemon = item.category == .launchDaemon
            LaunchServicesCleaner.unload(plistPath: item.path, isDaemon: isDaemon)
            let action: ActionTaken = isDaemon
                ? .unloadedLaunchDaemon(path: item.path)
                : .unloadedLaunchAgent(path: item.path)
            record(action)
        }

        // Step 2: Unregister from Launch Services
        LaunchServicesCleaner.unregister(appPath: appPath)
        record(.unregisteredFromLaunchServices(path: appPath))

        // Step 3: Remove TCC entries
        let tccItems = items.filter { $0.category == .tccPermissions }
        if !tccItems.isEmpty {
            let home = NSHomeDirectory()
            let tccPath = "\(home)/Library/Application Support/com.apple.TCC/TCC.db"
            let (_, errors) = TCCCleaner.removeEntries(bundleID: info.bundleIdentifier, dbPath: tccPath)
            for item in tccItems {
                let parts = item.path.split(separator: ":")
                let service = parts.count >= 3 ? String(parts[2]) : "unknown"
                record(.cleanedTCCEntry(bundleID: info.bundleIdentifier, service: service))
            }
            for error in errors {
                record(.failed(path: "TCC.db", error: error))
            }
        }

        // Step 4: Remove all files and directories (except launch items handled separately)
        let fileItems = items.filter { $0.category != .tccPermissions && $0.category != .launchAgent && $0.category != .launchDaemon }
        for item in fileItems {
            do {
                try fm.removeItem(atPath: item.path)
                if item.isDirectory {
                    record(.removedDirectory(path: item.path, category: item.category, sizeBytes: item.sizeBytes))
                } else {
                    record(.removedFile(path: item.path, category: item.category))
                }
            } catch {
                record(.failed(path: item.path, error: error.localizedDescription))
            }
        }

        // Step 5: Remove launch agent/daemon plist files (after unloading)
        for item in launchItems {
            do {
                try fm.removeItem(atPath: item.path)
                record(.removedFile(path: item.path, category: item.category))
            } catch {
                record(.failed(path: item.path, error: error.localizedDescription))
            }
        }

        return actions
    }

    private func record(_ action: ActionTaken) {
        actions.append(action)
        onAction?(action)
    }
}
