import Foundation

/// One person on an event's guest list. `isMe` marks the current user's own entry (the one whose answer is `CalendarEvent.status`).
public struct Attendee: Hashable, Sendable {
    /// Empty when the guest is known only by name (the demo data, or a typed name).
    public var email: String
    public var name: String?
    public var isOrganizer: Bool
    public var isMe: Bool
    public var isOptional: Bool
    public var status: ResponseStatus

    public init(email: String, name: String? = nil, isOrganizer: Bool = false, isMe: Bool = false, isOptional: Bool = false,
                status: ResponseStatus = .needsAction) {
        self.email = email; self.name = name; self.isOrganizer = isOrganizer; self.isMe = isMe; self.isOptional = isOptional; self.status = status
    }

    /// What the guest list shows: the name, else the address.
    public var label: String {
        let n = name?.trimmingCharacters(in: .whitespaces) ?? ""
        return n.isEmpty ? email : n
    }

    /// A typed or stored guest: "Name <address>", a bare address, or a plain name. Nil for blank text.
    public static func parse(_ text: String, status: ResponseStatus = .needsAction) -> Attendee? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let lt = t.firstIndex(of: "<"), let gt = t.lastIndex(of: ">"), lt < gt {
            let name = t[..<lt].trimmingCharacters(in: .whitespaces)
            let mail = t[t.index(after: lt)..<gt].trimmingCharacters(in: .whitespaces)
            return Attendee(email: mail, name: name.isEmpty ? nil : name, status: status)
        }
        return t.contains("@") && !t.contains(" ") ? Attendee(email: t, status: status) : Attendee(email: "", name: t, status: status)
    }
}
