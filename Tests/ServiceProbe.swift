import AppKit

let app = NSApplication.shared
let board = NSPasteboard(name: NSPasteboard.Name("iCalendifyTest-" + UUID().uuidString))
defer { board.releaseGlobally() }
board.setString("Let's meet tomorrow at 2 pm for one hour to discuss the next project milestone.", forType: .string)
let sent = NSPerformService("Add to Calendar with iCalendify", board)
print(sent ? "PASS: service accepted selected text" : "FAIL: service unavailable")
exit(sent ? 0 : 1)
