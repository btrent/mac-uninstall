import Foundation

// Parse arguments
let args = CommandLine.arguments

// Check for help
if args.contains("--help") || args.contains("-h") {
    print("""
    mac-uninstall - Complete macOS application uninstaller

    USAGE:
      sudo mac-uninstall <path-to-app>     Uninstall via command line
      sudo mac-uninstall                   Launch GUI mode

    OPTIONS:
      --dry-run    Scan and show what would be removed, without deleting
      --yes, -y    Skip confirmation prompt
      --help, -h   Show this help message

    EXAMPLES:
      sudo mac-uninstall /Applications/SomeApp.app
      sudo mac-uninstall --dry-run /Applications/SomeApp.app
      sudo mac-uninstall --yes /Applications/SomeApp.app
      sudo mac-uninstall    # launches GUI
    """)
    exit(0)
}

// Find the app path (first arg that isn't a flag)
let flags = args.dropFirst().filter { $0.hasPrefix("-") }
let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
let dryRun = flags.contains("--dry-run")
let skipConfirm = flags.contains("--yes") || flags.contains("-y")

if let appPath = positional.first {
    // CLI mode
    let cli = CLIMode(appPath: appPath, dryRun: dryRun, skipConfirm: skipConfirm)
    exit(cli.run())
} else {
    // GUI mode
    GUIApp.launch()
}
