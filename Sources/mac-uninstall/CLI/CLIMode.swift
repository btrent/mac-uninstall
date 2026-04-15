import Foundation

struct CLIMode {
    let appPath: String
    let dryRun: Bool
    let skipConfirm: Bool

    func run() -> Int32 {
        let uninstaller = AppUninstaller(appPath: appPath)

        // Validate
        do {
            try uninstaller.validate()
        } catch {
            printError(error.localizedDescription)
            return 1
        }

        // Scan
        printHeader("Scanning: \(appPath)")
        let scanResult: ScanResult
        do {
            scanResult = try uninstaller.scan()
        } catch {
            printError("Scan failed: \(error.localizedDescription)")
            return 1
        }

        guard !scanResult.foundItems.isEmpty else {
            printWarning("No associated files found.")
            return 0
        }

        // Display results
        printHeader("Found \(scanResult.foundItems.count) items (\(scanResult.formattedTotalSize))")
        print("")

        let grouped = Dictionary(grouping: scanResult.foundItems, by: \.category)
        for category in FileCategory.allCases {
            guard let items = grouped[category], !items.isEmpty else { continue }
            printBold("  \(category.rawValue) (\(items.count))")
            for item in items {
                let sizeStr = item.sizeBytes.map { $0 > 0 ? " (\(item.formattedSize))" : "" } ?? ""
                print("    \(item.path)\(sizeStr)")
            }
            print("")
        }

        if dryRun {
            printWarning("Dry run — no files were removed.")
            return 0
        }

        // Confirm
        if !skipConfirm {
            print("\u{1B}[1mProceed with uninstall? [y/N] \u{1B}[0m", terminator: "")
            guard let answer = readLine()?.lowercased(), answer == "y" || answer == "yes" else {
                print("Aborted.")
                return 0
            }
        }

        // Execute
        printHeader("Uninstalling \(scanResult.bundleInfo.bundleName)...")
        print("")

        uninstaller.onAction = { action in
            if action.isFailure {
                printError("  \(action)")
            } else {
                printSuccess("  \(action)")
            }
        }

        let actions = uninstaller.execute(items: scanResult.foundItems)

        // Summary
        let successes = actions.filter { !$0.isFailure }.count
        let failures = actions.filter { $0.isFailure }.count
        print("")
        printHeader("Complete")
        printSuccess("  \(successes) actions succeeded")
        if failures > 0 {
            printError("  \(failures) actions failed")
        }
        printBold("  Space freed: \(scanResult.formattedTotalSize)")

        return failures > 0 ? 2 : 0
    }
}

// MARK: - ANSI Output Helpers

private func printHeader(_ msg: String) {
    print("\u{1B}[1;36m\(msg)\u{1B}[0m")
}

private func printBold(_ msg: String) {
    print("\u{1B}[1m\(msg)\u{1B}[0m")
}

private func printSuccess(_ msg: String) {
    print("\u{1B}[32m\(msg)\u{1B}[0m")
}

private func printWarning(_ msg: String) {
    print("\u{1B}[33m\(msg)\u{1B}[0m")
}

private func printError(_ msg: String) {
    print("\u{1B}[31m\(msg)\u{1B}[0m")
}
