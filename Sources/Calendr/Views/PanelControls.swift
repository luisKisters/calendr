import SwiftUI
import AppKit
import CalendrKit

// Controls of the right column (design/mockup-v3/app.css "Detail", "today column, up next").

enum PanelMetrics {
    /// One column, one width: 320 including the hairline.
    static let width: CGFloat = 320
}

enum PanelFocus: Hashable { case title, date, start, end, place, guest, video, notes }

/// Segmented thumb (`--thumb`): lifted ink on ink, white on paper.
private let panelThumb = Color.dyn("#33333C", "#FFFFFF")

/// `.in`: a field that looks like text until hovered (wash) or focused (window colour, 1.5 pt ring).
/// Its text stays on the column line: the 7 pt padding hangs out to the left.
struct PanelInputChrome: ViewModifier {
    var focused: Bool
    var editable: Bool
    var bad = false
    var hang = true
    var height: CGFloat? = 26
    @State private var hover = false
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 7)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 6).fill(focused ? Theme.bg : (hover && editable ? Theme.hover : Color.clear)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(bad ? Theme.live : (focused ? Theme.focus : Color.clear), lineWidth: 1.5))
            .padding(.vertical, 1)
            .padding(.leading, hang ? -7 : 0)
            .onHover { hover = $0 }
            .animation(Motion.fast, value: hover)
            .animation(Motion.fast, value: focused)
    }
}

extension View {
    func panelInput(focused: Bool, editable: Bool, bad: Bool = false, hang: Bool = true, height: CGFloat? = 26) -> some View {
        modifier(PanelInputChrome(focused: focused, editable: editable, bad: bad, hang: hang, height: height))
    }
}

extension View {
    /// Placeholder in fg3 at regular weight (a TextField prompt takes the field's font and the system colour).
    func panelPlaceholder(_ text: String, when empty: Bool, font: Font = .ui(12.5)) -> some View {
        overlay(alignment: .topLeading) {
            if empty { Text(text).font(font).foregroundStyle(Theme.fg3).lineLimit(1).allowsHitTesting(false) }
        }
    }
}

/// `.in.is-bad`: a short shake.
struct PanelShake: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 3 * sin(travel * .pi * 2), y: 0))
    }
}

/// A field that commits on Return or when it loses focus (times, date, video link). A refused value puts the real one back with a shake;
/// an accepted one is replaced by the model's text ("930" becomes "09:30").
struct PanelCommitField: View {
    let value: String
    var width: CGFloat?
    var minWidth: CGFloat = 0
    var placeholder: String?
    var centered = false
    var tabular = false
    let editable: Bool
    let focusKey: PanelFocus
    var focus: FocusState<PanelFocus?>.Binding
    /// Returns false to refuse the text.
    let commit: (String) -> Bool
    var onReturn: () -> Void = {}
    @State private var text = ""
    @State private var bad = false
    @State private var shakes: CGFloat = 0
    /// A commit was accepted while the field kept the focus: take the model's text when it arrives.
    @State private var accepted = false

    var body: some View {
        let focused = focus.wrappedValue == focusKey
        let font: Font = tabular ? .calMono(12.5) : .ui(12.5)
        // the field is as wide as its text (`field-sizing: content`), or fixed
        Text(editable ? (text.isEmpty ? " " : text) : value).font(font).foregroundStyle(Theme.fg).lineLimit(1).fixedSize()
            .opacity(editable ? 0 : 1)
            .frame(width: width.map { $0 - 14 }, alignment: centered ? .center : .leading)
            .frame(minWidth: max(0, minWidth - 14), alignment: .leading)
            .overlay {
                if editable {
                    TextField("", text: $text)
                        .textFieldStyle(.plain).font(font).foregroundStyle(Theme.fg)
                        .multilineTextAlignment(centered ? .center : .leading)
                        .focused(focus, equals: focusKey)
                        .onSubmit { apply(); onReturn() }
                        .panelPlaceholder(placeholder ?? "", when: placeholder != nil && text.isEmpty)
                }
            }
        .panelInput(focused: focused && editable, editable: editable, bad: bad, hang: !centered)
        .modifier(PanelShake(travel: shakes))
        .onAppear { text = value }
        .onChange(of: value) { _, v in if !focused || !editable || accepted { text = v; accepted = false } }
        .onChange(of: focused) { _, f in
            guard !f && editable else { return }
            apply()
            text = value; accepted = false
        }
        .onChange(of: text) { _, _ in bad = false }
    }

    private func apply() {
        guard text != value else { return }
        if commit(text) { accepted = true } else {
            text = value
            withAnimation(Motion.slow) { shakes += 1 }
            after(0.01) { bad = true }
        }
    }
}

/// `.tg2`: 26 x 15 switch with its label, on its own line.
struct PanelSwitch: View {
    let label: String
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                ZStack(alignment: .leading) {
                    Capsule().fill(isOn ? Theme.act : Theme.bg3).frame(width: 26, height: 15)
                    Circle().fill(isOn ? Theme.onAct : Theme.fg2).frame(width: 11, height: 11).offset(x: isOn ? 13 : 2)
                }
                Text(label).font(.ui(12)).foregroundStyle(Theme.fg2)
            }
            .frame(height: 26).contentShape(Rectangle())
            .animation(Motion.base, value: isOn)
        }
        .buttonStyle(.plain)
    }
}

/// `.rsvp`: Yes / Maybe / No.
struct PanelRSVP: View {
    let status: ResponseStatus
    let editable: Bool
    let pick: (ResponseStatus) -> Void
    var body: some View {
        HStack(spacing: 0) {
            ForEach([(ResponseStatus.confirmed, "Yes"), (.tentative, "Maybe"), (.declined, "No")], id: \.0) { s, t in
                Button { if editable { pick(s) } } label: {
                    Text(t).font(.ui(12, .medium)).foregroundStyle(status == s ? Theme.fg : Theme.fg2)
                        .padding(.horizontal, 11).frame(height: 22)
                        .background(RoundedRectangle(cornerRadius: Radius.control - 1).fill(status == s ? panelThumb : Color.clear)
                            .shadow(color: status == s ? .black.opacity(0.2) : .clear, radius: 1, y: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: Radius.control + 1).fill(Theme.bg2))
        .animation(Motion.fast, value: status)
    }
}

/// `kbd`: 18 pt keycap.
struct PanelKbd: View {
    let text: String
    var onAct = false
    var body: some View {
        Text(text).font(.calMono(10.5, .medium)).foregroundStyle(onAct ? Theme.onAct : Theme.fg2)
            .padding(.horizontal, 4).frame(minWidth: 18, minHeight: 18)
            .background(RoundedRectangle(cornerRadius: 4).fill(onAct ? Theme.onAct.opacity(0.16) : Theme.bg2))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(onAct ? Color.clear : Theme.hair2, lineWidth: 1))
    }
}

/// `.btn--fill`: ink on the window, 28 pt (24 pt small).
struct PanelFillButton: View {
    let title: String
    var small = false
    var key: String?
    var fullWidth = false
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.ui(small ? 12 : 12.5, .semibold))
                if let key { PanelKbd(text: key, onAct: true) }
            }
            .foregroundStyle(Theme.onAct)
            .padding(.horizontal, small ? 8 : 10).frame(maxWidth: fullWidth ? .infinity : nil).frame(height: small ? 24 : 28)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(hover ? Theme.actHover : Theme.act))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// `.btn--s` text button with a hairline (`.btn--line`).
struct PanelLineButton: View {
    let title: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Text(title).font(.ui(12, .medium)).foregroundStyle(Theme.fg)
                .padding(.horizontal, 8).frame(height: 24)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(hover ? Theme.hover : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.hair2, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// `.btn--icon.btn--s`: 24 pt square, fg2, wash on hover.
struct PanelIconButton: View {
    let icon: PanelIcon.Name
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            PanelIcon(name: icon, color: hover ? Theme.fg : Theme.fg2)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(hover ? Theme.hover : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// `.add`: "+ Place" under the fields.
struct PanelAddChip: View {
    let title: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                PanelIcon(name: .plus, color: hover ? Theme.fg : Theme.fg3)
                Text(title).font(.ui(12)).foregroundStyle(hover ? Theme.fg : Theme.fg3)
            }
            .padding(.leading, 6).padding(.trailing, 8).frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Theme.hover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// `.gs__c`: a guest with initials and a remove button.
struct PanelGuestChip: View {
    let name: String
    let removable: Bool
    let remove: () -> Void
    @State private var hover = false
    var body: some View {
        HStack(spacing: 6) {
            Text(PanelText.initials(name)).font(.ui(8.5, .semibold)).tracking(0.17).foregroundStyle(Theme.fg2)
                .frame(width: 18, height: 18).background(Circle().fill(Theme.bg3))
            Text(name).font(.ui(12)).foregroundStyle(Theme.fg).lineLimit(1)
            if removable {
                Button(action: remove) {
                    PanelIcon(name: .x, size: 9, color: hover ? Theme.fg : Theme.fg3)
                        .frame(width: 16, height: 16).background(Circle().fill(hover ? Theme.bg3 : Color.clear)).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { hover = $0 }
            }
        }
        .padding(.leading, 3).padding(.trailing, removable ? 4 : 8).frame(height: 24)
        .background(Capsule().fill(Theme.bg2))
    }
}

/// Wrapping row (`flex-wrap`). A subview marked `.panelFill()` takes the rest of its line, or a new line when less than its minimum is left.
struct PanelFlow: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews) {
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y + (row.height - item.size.height) / 2),
                                           proposal: ProposedViewSize(item.size))
            }
        }
    }

    private struct Item { var index: Int; var x: CGFloat; var size: CGSize }
    private struct Row { var y: CGFloat; var height: CGFloat = 0; var width: CGFloat = 0; var items: [Item] = [] }

    private func arrange(width: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row(y: 0)]
        var x: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let fill = v[PanelFillKey.self]
            var size = v.sizeThatFits(.unspecified)
            if let minW = fill { size.width = max(minW, width.isFinite ? width - x : minW) }
            if x > 0 && x + (fill ?? size.width) > width {
                let r = rows[rows.count - 1]
                rows.append(Row(y: r.y + r.height + lineSpacing))
                x = 0
                if fill != nil { size.width = width.isFinite ? width : size.width }
            }
            size.width = min(size.width, width)
            rows[rows.count - 1].items.append(Item(index: i, x: x, size: size))
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            x += size.width + spacing
            rows[rows.count - 1].width = x - spacing
        }
        return rows
    }
}

private struct PanelFillKey: LayoutValueKey { static let defaultValue: CGFloat? = nil }

extension View {
    func panelFill(min: CGFloat) -> some View { layoutValue(key: PanelFillKey.self, value: min) }
}

/// Coloured dot for the calendar menu (NSMenu items cannot draw a SwiftUI shape).
enum PanelDot {
    nonisolated(unsafe) private static var cache: [String: NSImage] = [:]
    static func image(_ hex: String) -> NSImage {
        if let i = cache[hex] { return i }
        let img = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { r in
            NSColor(Color(hex: hex)).setFill()
            NSBezierPath(ovalIn: r).fill()
            return true
        }
        cache[hex] = img
        return img
    }
}
