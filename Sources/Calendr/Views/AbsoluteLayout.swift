import SwiftUI

/// Frame a child asks the parent `AbsoluteLayout` to place it at (parent coordinates, top-left origin).
struct PlacedFrame: LayoutValueKey { static let defaultValue: CGRect = .zero }

extension View {
    func placed(_ rect: CGRect) -> some View { layoutValue(key: PlacedFrame.self, value: rect) }
}

/// Positions hundreds of children at explicit rectangles without asking any of them for a size.
/// A ZStack does that work per child on every pass; this is what keeps week navigation inside a frame.
struct AbsoluteLayout: Layout {
    var size: CGSize
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { size }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for s in subviews {
            let r = s[PlacedFrame.self]
            s.place(at: CGPoint(x: bounds.minX + r.minX, y: bounds.minY + r.minY), anchor: .topLeading, proposal: ProposedViewSize(width: r.width, height: r.height))
        }
    }
}
