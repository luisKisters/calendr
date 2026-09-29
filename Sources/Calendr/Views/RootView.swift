import SwiftUI
import AppKit
import CalendrKit

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Theme.ink900
            HStack(spacing: 0) {
                if model.sidebarVisible {
                    SidebarView().transition(.move(edge: .leading).combined(with: .opacity))
                }
                CenterView()
                if model.rightPanelVisible {
                    RightPanelView().transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(Motion.slow, value: model.sidebarVisible)
            .animation(Motion.slow, value: model.rightPanelVisible)
            if !model.sidebarVisible {
                HStack(spacing: 0) {
                    IconButton(name: "sidebar.left", size: 16) { model.toggleSidebar() }.padding(.leading, 84)
                    Spacer()
                }.frame(maxHeight: .infinity, alignment: .top).padding(.top, 12)
            }
            OverlayHost()
        }
        .ignoresSafeArea()
        .preferredColorScheme(model.settings.appearance == .dark ? .dark : model.settings.appearance == .light ? .light : nil)
        .font(.system(size: 13))
        .onChange(of: model.settings.reduceMotion) { _, v in Motion.override = v }
    }
}

/// Shown in place of the calendar when EventKit access has not been granted.
struct AccessEmptyState: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(spacing: 0) {
            EmptyArt(kind: .lock, size: 96).padding(.bottom, 14)
            Text("Calendr needs access to your calendars").font(.system(size: 22, weight: .semibold)).tracking(-0.4).foregroundStyle(Theme.paper)
            Text("Events stay on this Mac. Calendr reads them through\nmacOS and never sends them anywhere.")
                .font(.system(size: 13)).foregroundStyle(Theme.haze).multilineTextAlignment(.center).lineSpacing(3).padding(.top, 8)
            HStack(spacing: 8) {
                if model.authState == .notDetermined { PrimaryButton(title: "Allow access") { model.requestAccess() } }
                else { PrimaryButton(title: "Open Privacy Settings") { model.openPrivacySettings() } }
                SecondaryButton(title: "How it works") { model.showToast("Calendr reads Google and iCloud calendars through macOS EventKit") }
            }.padding(.top, 16)
            HStack(spacing: 6) {
                SFIcon(name: "lock", size: 11, color: Theme.hazeDim)
                Text("System Settings, Privacy and Security, Calendars").font(.system(size: 11.5)).foregroundStyle(Theme.hazeDim)
            }.padding(.top, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RadialGradient(colors: [Theme.actSoft, .clear], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 360))
    }
}
