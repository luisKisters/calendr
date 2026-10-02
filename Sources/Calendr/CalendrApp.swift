import SwiftUI
import AppKit
import CalendrKit

/// Process-wide singletons for the real app (the model is shared by the main window and the menu bar item).
@MainActor
enum AppContext {
    static let model: AppModel = {
        let store: CalendarStore = launchOptions.demo ? DemoStore() : EventKitStore()
        return AppModel(store: store, options: launchOptions)
    }()
}

struct CalendrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let model = AppContext.model

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 1100, minHeight: 700)
                .background(WindowConfigurator(model: model))
                .background(MainWindowOpener())
                .onAppear {
                    guard launchOptions.printLaunch else { return }
                    // Two run-loop turns later the first frame has been laid out and committed.
                    DispatchQueue.main.async { DispatchQueue.main.async {
                        let ms = Date().timeIntervalSince(Perf.processStart()) * 1000
                        print(String(format: "launch to interactive window: %.0f ms", ms))
                        let fr = NSApp.windows.first { !($0 is NSPanel) }?.firstResponder
                        print("first responder: \(fr.map { String(describing: type(of: $0)) } ?? "none")")
                        fflush(stdout)
                        exit(0)
                    } }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .commands { AppCommands(model: model) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            KeyRouter.shared.install(model: AppContext.model)
            let bar = MenuBarController(model: AppContext.model)
            MenuBarController.shared = bar
            MenuBarHotKey.register()
            if CommandLine.arguments.contains("--dump-menubar") {
                print(bar.dump())
                fflush(stdout)
                exit(0)
            }
            if launchOptions.demo { NSApp.activate(ignoringOtherApps: true) }
            if CommandLine.arguments.contains("--open-menubar") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { _ = MenuBarControl.open() }
            }
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { MenuBarHotKey.unregister() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct AppCommands: Commands {
    let model: AppModel
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings\u{2026}") { model.handle(.settings) }.keyboardShortcut(",")
        }
        CommandGroup(replacing: .newItem) {
            Button("New Event") { model.handle(.createEvent) }
            Button("Refresh") { model.handle(.refresh) }.keyboardShortcut("r")
        }
    }
}

/// Hidden title bar, traffic lights inline with the sidebar, dark appearance.
struct WindowConfigurator: NSViewRepresentable {
    let model: AppModel
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            WindowChrome.apply(to: w)
            // No text field may start focused: single-key shortcuts (T, J, C ...) only work outside text fields.
            if w.firstResponder is NSText { w.makeFirstResponder(nil) }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum WindowChrome {
    @MainActor static func apply(to w: NSWindow) {
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.styleMask.insert(.fullSizeContentView)
        w.isMovableByWindowBackground = false
        w.minSize = NSSize(width: 1100, height: 700)
        w.animationBehavior = .none
        w.backgroundColor = NSColor(Theme.bg)
    }
}
