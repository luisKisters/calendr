import SwiftUI
import AppKit
import CalendrKit

// Controls of the right column (design/mockup-v4 `.ds`, from the v3 "Detail" and "today column, up next" rules).

enum PanelMetrics {
    /// One column, one width: 320 including the hairline.
    static let width: CGFloat = 320
}

enum PanelFocus: Hashable { case title, date, start, end, place, guest, video, notes }

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
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(focused ? Theme.bg : (hover && editable ? Theme.hover : Color.clear)))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(bad ? Theme.live : (focused ? Theme.focus : Color.clear), lineWidth: 1.5))
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
    func panelPlaceholder(_ text: String, when empty: Bool, font: Font = .text) -> some View {
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
        let font: Font = tabular ? .textTab : .text
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
                Text(label).font(.text).foregroundStyle(Theme.fg2)
            }
            .frame(height: 26).contentShape(Rectangle())
            .animation(Motion.base, value: isOn)
        }
        .buttonStyle(.plain)
    }
}

/// `kbd`: a shortcut hint (now plain grey text, see `Keycap`).
typealias PanelKbd = Keycap

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
                Text(title).font(.textSemibold)
                if let key { PanelKbd(text: key, onAct: true) }
            }
            .foregroundStyle(Theme.onAct)
            .padding(.horizontal, small ? 8 : 10).frame(maxWidth: fullWidth ? .infinity : nil).frame(height: small ? Dim.row : Dim.field)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(hover ? Theme.actHover : Theme.act))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// `.ibtn`: 26 pt square, radius 6, fg2, wash on hover.
struct PanelIconButton: View {
    let icon: PanelIcon.Name
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            PanelIcon(name: icon, size: Dim.iconGlyph, color: hover ? Theme.fg : Theme.fg2)
                .frame(width: Dim.iconButton, height: Dim.iconButton)
                .background(RoundedRectangle(cornerRadius: Radius.row).fill(hover ? Theme.hover : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}
