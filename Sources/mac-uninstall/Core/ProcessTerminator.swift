import Foundation
import AppKit

struct ProcessTerminator {
    struct MatchedProcess: Hashable {
        let pid: Int32
        let name: String
        let path: String?
        let bundleIdentifier: String?
        let matchReason: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(pid)
        }

        static func == (lhs: MatchedProcess, rhs: MatchedProcess) -> Bool {
            lhs.pid == rhs.pid
        }
    }

    enum TerminationResult {
        case terminated(pid: Int32, name: String, graceful: Bool)
        case failed(pid: Int32, name: String, error: String)
        case skipped(pid: Int32, reason: String)
    }

    static func findProcesses(bundleInfo: BundleInfo, appPath: String) -> [MatchedProcess] {
        var matched = Set<MatchedProcess>()

        // Find GUI apps via NSWorkspace
        for app in NSWorkspace.shared.runningApplications {
            guard let pid = Optional(app.processIdentifier), pid > 0 else { continue }

            var matchReason: String? = nil

            // Match by bundle identifier
            if let appBundleID = app.bundleIdentifier,
               appBundleID.lowercased() == bundleInfo.bundleIdentifier.lowercased() {
                matchReason = "bundle identifier match"
            }
            // Match by app path
            else if let appURL = app.bundleURL,
                    appURL.path.hasPrefix(appPath) {
                matchReason = "path under app bundle"
            }
            // Match by vendor prefix in bundle identifier
            else if let vendorPrefix = bundleInfo.vendorPrefix,
                    let appBundleID = app.bundleIdentifier,
                    appBundleID.lowercased().hasPrefix(vendorPrefix.lowercased()) {
                matchReason = "vendor prefix match"
            }

            if let reason = matchReason {
                matched.insert(MatchedProcess(
                    pid: pid,
                    name: app.localizedName ?? "Unknown",
                    path: app.bundleURL?.path,
                    bundleIdentifier: app.bundleIdentifier,
                    matchReason: reason
                ))
            }
        }

        // Find background processes via pgrep/ps
        if let execName = bundleInfo.executableName {
            let backgroundProcesses = findBackgroundProcesses(executableName: execName, appPath: appPath)
            for proc in backgroundProcesses {
                matched.insert(proc)
            }
        }

        // Also search by bundle name
        for searchName in bundleInfo.searchNames {
            let procs = findBackgroundProcesses(executableName: searchName, appPath: appPath)
            for proc in procs {
                matched.insert(proc)
            }
        }

        return Array(matched)
    }

    private static func findBackgroundProcesses(executableName: String, appPath: String) -> [MatchedProcess] {
        var results: [MatchedProcess] = []

        // Use pgrep to find PIDs by name
        let pgrepProcess = Process()
        pgrepProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrepProcess.arguments = ["-i", executableName]
        let pgrepPipe = Pipe()
        pgrepProcess.standardOutput = pgrepPipe
        pgrepProcess.standardError = Pipe()

        do {
            try pgrepProcess.run()
            pgrepProcess.waitUntilExit()
        } catch {
            return results
        }

        let pgrepData = pgrepPipe.fileHandleForReading.readDataToEndOfFile()
        guard let pgrepOutput = String(data: pgrepData, encoding: .utf8) else { return results }

        let pids = pgrepOutput.split(separator: "\n").compactMap { Int32($0) }

        for pid in pids {
            // Get process info via ps
            let psProcess = Process()
            psProcess.executableURL = URL(fileURLWithPath: "/bin/ps")
            psProcess.arguments = ["-p", String(pid), "-o", "comm="]
            let psPipe = Pipe()
            psProcess.standardOutput = psPipe
            psProcess.standardError = Pipe()

            do {
                try psProcess.run()
                psProcess.waitUntilExit()
            } catch {
                continue
            }

            let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
            let processName = String(data: psData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? executableName

            // Get full path
            let pathProcess = Process()
            pathProcess.executableURL = URL(fileURLWithPath: "/bin/ps")
            pathProcess.arguments = ["-p", String(pid), "-o", "comm="]
            let pathPipe = Pipe()
            pathProcess.standardOutput = pathPipe
            pathProcess.standardError = Pipe()

            var processPath: String? = nil
            do {
                try pathProcess.run()
                pathProcess.waitUntilExit()
                let pathData = pathPipe.fileHandleForReading.readDataToEndOfFile()
                processPath = String(data: pathData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {}

            results.append(MatchedProcess(
                pid: pid,
                name: processName,
                path: processPath,
                bundleIdentifier: nil,
                matchReason: "executable name match"
            ))
        }

        return results
    }

    static func terminate(processes: [MatchedProcess], gracefulTimeoutSeconds: Double = 3.0) -> [TerminationResult] {
        var results: [TerminationResult] = []
        let ownPid = getpid()

        for proc in processes {
            // Skip our own process
            if proc.pid == ownPid {
                results.append(.skipped(pid: proc.pid, reason: "own process"))
                continue
            }

            // Check if it's a GUI app we can terminate gracefully
            if let runningApp = NSRunningApplication(processIdentifier: proc.pid) {
                let terminated = runningApp.terminate()

                if terminated {
                    // Wait for graceful termination
                    let deadline = Date().addingTimeInterval(gracefulTimeoutSeconds)
                    var gracefullyTerminated = false

                    while Date() < deadline {
                        if runningApp.isTerminated {
                            gracefullyTerminated = true
                            break
                        }
                        Thread.sleep(forTimeInterval: 0.1)
                    }

                    if gracefullyTerminated {
                        results.append(.terminated(pid: proc.pid, name: proc.name, graceful: true))
                        continue
                    }

                    // Force terminate if still running
                    if runningApp.forceTerminate() {
                        results.append(.terminated(pid: proc.pid, name: proc.name, graceful: false))
                    } else {
                        results.append(.failed(pid: proc.pid, name: proc.name, error: "force termination failed"))
                    }
                } else {
                    // Try force terminate directly
                    if runningApp.forceTerminate() {
                        results.append(.terminated(pid: proc.pid, name: proc.name, graceful: false))
                    } else {
                        results.append(.failed(pid: proc.pid, name: proc.name, error: "termination refused"))
                    }
                }
            } else {
                // Background process - use signals
                let result = terminateWithSignals(pid: proc.pid, name: proc.name, timeout: gracefulTimeoutSeconds)
                results.append(result)
            }
        }

        return results
    }

    private static func terminateWithSignals(pid: Int32, name: String, timeout: Double) -> TerminationResult {
        // First try SIGTERM for graceful shutdown
        if kill(pid, SIGTERM) != 0 {
            let errorCode = errno
            if errorCode == ESRCH {
                return .skipped(pid: pid, reason: "process already terminated")
            }
            return .failed(pid: pid, name: name, error: String(cString: strerror(errorCode)))
        }

        // Wait for graceful termination
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if kill(pid, 0) != 0 && errno == ESRCH {
                return .terminated(pid: pid, name: name, graceful: true)
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Still running, use SIGKILL
        if kill(pid, SIGKILL) != 0 {
            let errorCode = errno
            if errorCode == ESRCH {
                return .terminated(pid: pid, name: name, graceful: true)
            }
            return .failed(pid: pid, name: name, error: String(cString: strerror(errorCode)))
        }

        // Verify it's dead
        Thread.sleep(forTimeInterval: 0.1)
        if kill(pid, 0) != 0 && errno == ESRCH {
            return .terminated(pid: pid, name: name, graceful: false)
        }

        return .failed(pid: pid, name: name, error: "process still running after SIGKILL")
    }
}
