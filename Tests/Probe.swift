import Foundation

@main
struct Probe {
    @MainActor static func main() async {
        let ai = LocalEventAI()
        if let message = ai.unavailableMessage {
            print("UNAVAILABLE: \(message)")
            exit(2)
        }
        print("MODEL_AVAILABLE")
        let samples = [
            "Let's meet tomorrow at 2 pm for one hour to discuss the next project milestone.",
            "Lunch with Sarah",
            "Team workshop on 18 November 2026, 10:00–12:00 at Main Hall."
        ]
        for sample in samples {
            let begin = Date()
            do {
                let result = try await ai.extract(sample)
                print(String(format: "%.2f seconds", Date().timeIntervalSince(begin)))
                print(String(data: try JSONEncoder().encode(result), encoding: .utf8)!)
            } catch {
                print("ERROR: \(error)")
                exit(1)
            }
        }
    }
}
