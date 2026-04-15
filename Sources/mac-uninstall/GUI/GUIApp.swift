import SwiftUI
import AppKit

// MARK: - View Model

final class GUIViewModel: ObservableObject {
    enum State {
        case welcome
        case scanResults(ScanResult, [SelectableItem])
        case results([ActionTaken])
    }

    struct SelectableItem: Identifiable {
        let id: UUID
        let foundItem: FoundItem
        var selected: Bool
    }

    @Published var state: State = .welcome
    @Published var isDropTargeted = false
    @Published var errorMessage: String?

    func handleAppPath(_ path: String) {
        guard path.hasSuffix(".app") else {
            errorMessage = "Not a valid .app bundle."
            return
        }
        errorMessage = nil

        let uninstaller = AppUninstaller(appPath: path)
        do {
            try uninstaller.validate()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let scanResult: ScanResult
        do {
            scanResult = try uninstaller.scan()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let items = scanResult.foundItems.map { item in
            SelectableItem(id: item.id, foundItem: item, selected: item.selected)
        }
        state = .scanResults(scanResult, items)
    }

    func performUninstall(scanResult: ScanResult, items: [SelectableItem]) {
        let selectedFoundItems = items.filter(\.selected).map(\.foundItem)
        let uninstaller = AppUninstaller(appPath: scanResult.appPath)
        let actions = uninstaller.execute(items: selectedFoundItems)
        state = .results(actions)
    }

    func reset() {
        state = .welcome
        errorMessage = nil
        isDropTargeted = false
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var viewModel = GUIViewModel()

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .welcome:
                WelcomeView(viewModel: viewModel)
            case .scanResults(let scanResult, let items):
                ScanResultsView(viewModel: viewModel, scanResult: scanResult, items: items)
            case .results(let actions):
                ResultsView(viewModel: viewModel, actions: actions)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @ObservedObject var viewModel: GUIViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            dropZone

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
            }

            Button("Choose App...") {
                openFilePicker()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(40)
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.circle")
                .font(.system(size: 64))
                .foregroundColor(viewModel.isDropTargeted ? .accentColor : .secondary)

            Text("Drop an .app here to uninstall")
                .font(.title2)
                .foregroundColor(.primary)

            Text("or use the button below")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    viewModel.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(viewModel.isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension == "app" else {
                DispatchQueue.main.async {
                    viewModel.errorMessage = "Please drop an .app bundle."
                }
                return
            }
            DispatchQueue.main.async {
                viewModel.handleAppPath(url.path)
            }
        }
        return true
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select an Application"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.handleAppPath(url.path)
        }
    }
}

// MARK: - Scan Results View

struct ScanResultsView: View {
    @ObservedObject var viewModel: GUIViewModel
    let scanResult: ScanResult
    @State var items: [GUIViewModel.SelectableItem]

    init(viewModel: GUIViewModel, scanResult: ScanResult, items: [GUIViewModel.SelectableItem]) {
        self.viewModel = viewModel
        self.scanResult = scanResult
        self._items = State(initialValue: items)
    }

    private var groupedItems: [(FileCategory, [Binding<GUIViewModel.SelectableItem>])] {
        let bindings: [Binding<GUIViewModel.SelectableItem>] = items.indices.map { index in
            Binding(
                get: { items[index] },
                set: { items[index] = $0 }
            )
        }

        var grouped: [FileCategory: [Binding<GUIViewModel.SelectableItem>]] = [:]
        for binding in bindings {
            let category = binding.wrappedValue.foundItem.category
            grouped[category, default: []].append(binding)
        }

        return FileCategory.allCases.compactMap { category in
            guard let group = grouped[category], !group.isEmpty else { return nil }
            return (category, group)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(scanResult.bundleInfo.bundleName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(scanResult.bundleInfo.bundleIdentifier)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 16)

            Divider()

            // Scrollable item list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(groupedItems, id: \.0) { category, bindings in
                        Section {
                            ForEach(bindings, id: \.wrappedValue.id) { $item in
                                HStack {
                                    Toggle(isOn: $item.selected) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.foundItem.path)
                                                .font(.system(.body, design: .monospaced))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Text(item.foundItem.formattedSize)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        } header: {
                            Text(category.rawValue)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Text("Total size: \(scanResult.formattedTotalSize)")
                    .font(.callout)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Cancel") {
                    viewModel.reset()
                }
                .keyboardShortcut(.cancelAction)

                Button("Uninstall") {
                    viewModel.performUninstall(scanResult: scanResult, items: items)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
    }
}

// MARK: - Results View

struct ResultsView: View {
    @ObservedObject var viewModel: GUIViewModel
    let actions: [ActionTaken]

    private var successCount: Int { actions.filter { !$0.isFailure }.count }
    private var failureCount: Int { actions.filter { $0.isFailure }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Uninstall Complete")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.vertical, 16)

            Divider()

            // Action list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: action.isFailure ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(action.isFailure ? .red : .green)
                                .font(.body)

                            Text(action.description)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Summary footer
            HStack {
                HStack(spacing: 16) {
                    Label("\(successCount) succeeded", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    if failureCount > 0 {
                        Label("\(failureCount) failed", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .font(.callout)

                Spacer()

                Button("Done") {
                    viewModel.reset()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
    }
}

// MARK: - App Delegate

final class GUIAppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "mac-uninstall"
        window.minSize = NSSize(width: 700, height: 500)
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        true
    }
}

// MARK: - Public Entry Point

enum GUIApp {
    static func launch() {
        let app = NSApplication.shared
        let delegate = GUIAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
