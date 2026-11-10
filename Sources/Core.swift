import Foundation

enum CalendarDestinationPolicy {
    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    static func allows(sourceName: String, isCalDAV: Bool, writable: Bool) -> Bool {
        writable && isCalDAV && normalized(sourceName) == "icloud"
    }
}

struct EventDraft {
    var title: String
    var start: Date
    var end: Date
    var allDay = false
    var location = ""
    var source: String
    var notices: [String] = []

    static func blank(source: String, now: Date = Date(), calendar: Calendar = .current) -> EventDraft {
        let nextHour = calendar.date(byAdding: .hour, value: 1,
                                     to: calendar.dateInterval(of: .hour, for: now)!.start)!
        let firstLine = source.split(whereSeparator: \.isNewline).first.map(String.init) ?? "New event"
        return EventDraft(title: String(firstLine.prefix(100)), start: nextHour,
                          end: nextHour.addingTimeInterval(3600), source: source,
                          notices: ["Choose a date and time. A one-hour placeholder is shown."])
    }

    var validationError: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter an event title." }
        if end <= start { return "The end must be after the start." }
        return nil
    }
}
