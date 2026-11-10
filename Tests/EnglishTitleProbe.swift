import Foundation
import NaturalLanguage

@main struct EnglishTitleProbe {
    @MainActor static func main() async {
        let ai = LocalEventAI()
        if let message = ai.unavailableMessage { print(message); exit(2) }
        let samples = [
            "Let's meet tomorrow at 2 pm to discuss the next project milestone.",
            "Projektbesprechung am 18. November um 14 Uhr."
        ]
        for source in samples {
            print("INPUT: \(source)")
            do {
                let start = Date()
                let result = try await ai.extract(source)
                let recognizer = NLLanguageRecognizer()
                recognizer.processString(result.title)
                print("English: \(result.title) [\(recognizer.dominantLanguage?.rawValue ?? "unknown")] \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
                guard !result.title.isEmpty,
                      recognizer.dominantLanguage?.rawValue == "en" else { exit(1) }
            } catch { print("English: \(error)"); exit(1) }
        }
    }
}
