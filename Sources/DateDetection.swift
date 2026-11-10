import Foundation

enum NativeEventParser {
    static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func draft(source: String, now: Date = Date()) -> EventDraft {
        var draft = EventDraft.blank(source: source, now: now)
        draft.location = explicitLocation(source)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return draft }
        let results = detector.matches(in: source, range: NSRange(source.startIndex..., in: source))
        // A bare clock time is not evidence for choosing today's date.
        let dated = results.filter { result in
            guard let range = Range(result.range, in: source) else { return false }
            return hasDate(String(source[range]))
        }
        guard let result = dated.first, let date = result.date,
              let range = Range(result.range, in: source) else { return draft }
        let expression = String(source[range])
        let timed = hasTime(expression)
        let calendar = Calendar.current
        draft.start = timed ? date : calendar.startOfDay(for: date)
        draft.allDay = !timed
        draft.notices = []
        if timed {
            if result.duration > 0 {
                draft.end = date.addingTimeInterval(result.duration)
            } else if let duration = statedDuration(source) {
                draft.end = date.addingTimeInterval(duration)
            } else {
                draft.end = date.addingTimeInterval(3600)
                draft.notices.append("No duration was detected; set to one hour.")
            }
        } else {
            // Data detectors give the last included date of a date-only range.
            let lastDay = calendar.startOfDay(for: date.addingTimeInterval(result.duration))
            draft.end = calendar.date(byAdding: .day, value: 1, to: lastDay)!
            draft.notices.append("No time was detected; shown as an all-day event.")
        }
        if dated.count > 1 {
            draft.notices.append("Several dates were found. The first is selected; check which event you want.")
        }
        if matches(#"\b\d{1,2}[/.]\d{1,2}(?:[/.]\d{2,4})?\b"#, expression) {
            draft.notices.append("Check the numeric date: macOS interpreted it using your region settings.")
        }
        if let sourceZone = result.timeZone, sourceZone != .current {
            draft.notices.append("Converted from \(sourceZone.identifier) to \(TimeZone.current.identifier).")
        }
        if draft.start < (timed ? now : calendar.startOfDay(for: now)) {
            draft.notices.append("This date is in the past. Please check it.")
        }
        return draft
    }

    private static func hasDate(_ expression: String) -> Bool {
        matches(#"\b(today|tomorrow|tonight|yesterday|heute|morgen|übermorgen|gestern|monday|tuesday|wednesday|thursday|friday|saturday|sunday|montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag|january|february|march|april|may|june|july|august|september|october|november|december|januar|februar|märz|mai|juni|juli|oktober|dezember|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec|mon|tue|wed|thu|fri|sat|sun)\b|\b\d{4}-\d{2}-\d{2}(?=T|\b)|\b\d{1,2}[/.]\d{1,2}\b|\bin\s+\d+\s+(minutes?|hours?|days?|weeks?|minuten?|stunden?|tagen?|wochen?)\b"#, expression)
    }

    private static func hasTime(_ expression: String) -> Bool {
        matches(#"(?:\b|T)\d{1,2}:\d{2}\b|\b\d{1,2}\s*[ap]\.?m\.?\b|\b(noon|midnight|mittag|mitternacht)\b|\b\d{1,2}\s*uhr\b|\b(at|um)\s+\d{1,2}\b|\bin\s+\d+\s+(minutes?|hours?|minuten?|stunden?)\b"#, expression)
    }

    private static func explicitLocation(_ source: String) -> String {
        if let regex = try? NSRegularExpression(pattern: #"(?im)^\s*(?:location|where|ort|treffpunkt)\s*:\s*([^\n]+)"#),
           let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
           let range = Range(match.range(at: 1), in: source) {
            return String(source[range].prefix(500))
        }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue | NSTextCheckingResult.CheckingType.link.rawValue) else { return "" }
        for result in detector.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            if result.resultType == .address, let range = Range(result.range, in: source) {
                return String(source[range].prefix(500))
            }
            if let url = result.url, let host = url.host?.lowercased(),
               ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com"].contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
                return String(url.absoluteString.prefix(500))
            }
        }
        return ""
    }

    private static func statedDuration(_ source: String) -> TimeInterval? {
        let pattern = #"\b(?:for|für)\s+(\d+(?:[.,]\d+)?|one|two|three|half|an?|eine?|zwei|drei)\s+(?:an?\s+)?(hours?|hrs?|minutes?|mins?|stunden?|minuten?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let numberRange = Range(match.range(at: 1), in: source),
              let unitRange = Range(match.range(at: 2), in: source) else { return nil }
        let word = source[numberRange].lowercased()
        let numbers: [String: Double] = ["one": 1, "a": 1, "an": 1, "ein": 1, "eine": 1, "two": 2, "zwei": 2, "three": 3, "drei": 3, "half": 0.5]
        guard let amount = Double(word.replacingOccurrences(of: ",", with: ".")) ?? numbers[word] else { return nil }
        let unit = source[unitRange].lowercased()
        let seconds = amount * (unit.hasPrefix("min") ? 60 : 3600)
        return seconds > 0 && seconds <= 7 * 86400 ? seconds : nil
    }
}
