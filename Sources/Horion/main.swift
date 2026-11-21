import AppKit

Typeface.register()
let launchOptions = LaunchOptions.parse(CommandLine.arguments)
if launchOptions.isHeadless {
    MainActor.assumeIsolated { HeadlessRunner.start(launchOptions) }
} else {
    if !launchOptions.demo { LegacyMigration.run() }
    HorionApp.main()
}
