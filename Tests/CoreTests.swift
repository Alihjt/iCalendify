import Foundation

@main struct CoreTests {
    static func main() {
        // Fixed test timezone: assertions must not depend on the developer's region.
        NSTimeZone.default = TimeZone(identifier: "Europe/London")!
        precondition(CalendarDestinationPolicy.allows(sourceName: "iCloud", isCalDAV: true, writable: true))
        precondition(CalendarDestinationPolicy.allows(sourceName: " ICLOUD ", isCalDAV: true, writable: true))
        precondition(!CalendarDestinationPolicy.allows(sourceName: "Google", isCalDAV: true, writable: true))
        precondition(!CalendarDestinationPolicy.allows(sourceName: "iCloud", isCalDAV: false, writable: true))
        precondition(!CalendarDestinationPolicy.allows(sourceName: "iCloud", isCalDAV: true, writable: false))
        precondition(!CalendarDestinationPolicy.allows(sourceName: "", isCalDAV: true, writable: true))
        let allDay = NativeEventParser.draft(source: "Workshop on 18 November 2026")
        precondition(allDay.allDay && allDay.end.timeIntervalSince(allDay.start) == 86400)
        let dstDay = NativeEventParser.draft(source: "Workshop on 28 March 2027")
        precondition(dstDay.allDay && dstDay.end.timeIntervalSince(dstDay.start) == 23 * 3600,
                     "All-day end must be next calendar day across DST")
        let past = NativeEventParser.draft(source: "Meeting on 1 January 2025 at noon")
        precondition(past.notices.contains { $0.contains("past") })
        var invalid = EventDraft.blank(source: "Meeting")
        invalid.title = " \n "
        precondition(invalid.validationError != nil)
        invalid.title = "Meeting"; invalid.end = invalid.start
        precondition(invalid.validationError != nil)
        let undated = NativeEventParser.draft(source: "Lunch with Sarah")
        precondition(undated.notices.first?.contains("Choose a date") == true)
        let timeOnly = NativeEventParser.draft(source: "Lunch at 2 pm")
        precondition(timeOnly.notices.first?.contains("Choose a date") == true, "Never assume today from a clock time alone")
        let ranged = NativeEventParser.draft(source: "Workshop on 18 November 2026, 10:00–12:00")
        precondition(!ranged.allDay && ranged.end.timeIntervalSince(ranged.start) == 7200)
        let duration = NativeEventParser.draft(source: "Meet on 18 November 2026 at 2 pm for one hour")
        precondition(!duration.allDay && duration.end.timeIntervalSince(duration.start) == 3600)
        precondition(!duration.notices.contains { $0.contains("duration") })
        let ninety = NativeEventParser.draft(source: "Meet on 18 November 2026 at 2 pm for 90 minutes")
        precondition(ninety.end.timeIntervalSince(ninety.start) == 5400)
        let rangeDays = NativeEventParser.draft(source: "Workshop from 18 to 20 November 2026")
        precondition(rangeDays.allDay && rangeDays.end.timeIntervalSince(rangeDays.start) == 3 * 86400)
        let numeric = NativeEventParser.draft(source: "Meeting on 11/12 at 15:00")
        precondition(numeric.notices.contains { $0.contains("numeric date") })
        let multi = NativeEventParser.draft(source: "Meeting on 18 November 2026 at 10 am. Lunch on 20 November 2026 at noon.")
        precondition(multi.notices.contains { $0.contains("Several dates") })
        let located = NativeEventParser.draft(source: "Workshop tomorrow at noon\nLocation: Main Hall")
        precondition(located.location == "Main Hall")
        let noLocation = NativeEventParser.draft(source: "Discuss the next project milestone tomorrow at 2 pm")
        precondition(noLocation.location.isEmpty, "No location may be inferred from the meeting topic")
        let video = NativeEventParser.draft(source: "Meet tomorrow at noon: https://meet.google.com/abc-defg-hij")
        precondition(video.location == "https://meet.google.com/abc-defg-hij")
        print("PASS: all-day events, DST, past dates, invalid saves, explicit locations and meeting links")
        print("PASS: native date ranges, date-only ranges, durations, no-date text, time-only text, numeric and multiple dates")
        print("PASS: only writable iCloud calendars can be destinations")
    }
}
