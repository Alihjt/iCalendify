import Foundation

let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
for sample in [
    "Let's meet tomorrow at 2 pm for one hour to discuss the next project milestone.",
    "Lunch with Sarah", "Lunch at 2 pm", "Workshop tomorrow", "Team workshop on 18 November 2026, 10:00–12:00 at Main Hall.",
    "Meet next Tuesday at 3 pm", "Meeting on 11/12 at 15:00", "Meeting on 18 November 2026 at 10 am for 90 minutes",
    "Workshop from 18 to 20 November 2026", "Tomorrow at 2 pm ET", "Meeting tomorrow 10:00-11:30"
] {
    print(sample)
    for result in detector.matches(in: sample, range: NSRange(sample.startIndex..., in: sample)) {
        let matched = String(sample[Range(result.range, in: sample)!])
        print("MATCH", matched, "DATE", result.date as Any, "DURATION", result.duration, "ZONE", result.timeZone as Any)
    }
}
