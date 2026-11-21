import AppKit

/// A press in the sidebar or the header settles the draft and closes the "+N" stack (kept with a title, dropped without), as a press on the grid does.
/// The grid, the day header and the panel handle their own presses; sheets and the command menu keep the draft.
@MainActor
final class PanelClickAway {
    static let shared = PanelClickAway()
    private var monitor: Any?
    private weak var model: AppModel?

    func install(model: AppModel) {
        self.model = model
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            MainActor.assumeIsolated {
                if let self, let model = self.model, let w = event.window, !(w is NSPanel), let content = w.contentView,
                   Self.settles(at: event.locationInWindow, in: content.bounds.size, model: model) {
                    model.settleDraft()
                }
                if let self, let model = self.model, let w = event.window, !(w is NSPanel), let content = w.contentView,
                   Self.closesStack(at: event.locationInWindow, in: content.bounds.size, model: model) {
                    model.closeStack()
                }
            }
            return event
        }
    }

    /// A press outside the open "+N" stack and outside the grid closes the stack (the grid closes it itself, so a press on "+N" toggles).
    /// `point` in window coordinates (bottom-left origin).
    static func closesStack(at point: CGPoint, in size: CGSize, model: AppModel) -> Bool {
        guard model.visibleStack != nil else { return false }
        let p = CGPoint(x: point.x, y: size.height - point.y)
        return !model.gridState.stackFrame.contains(p) && !model.gridViewport.contains(p)
    }

    /// `point` in window coordinates (bottom-left origin).
    static func settles(at point: CGPoint, in size: CGSize, model: AppModel) -> Bool {
        guard model.draft != nil, model.overlay == nil else { return false }
        let side = model.sidebarVisible ? ChromeDim.sidebarWidth : 0
        let fromTop = size.height - point.y
        return point.x < side || (point.x < size.width - PanelMetrics.width && fromTop < ChromeDim.headerHeight)
    }
}
