import AppKit
import SwiftUI
import EventKit

@MainActor
final class EventState: ObservableObject {
    @Published var draft = EventDraft.blank(source: "")
    @Published var input = ""
    @Published var hasDraft = false
    @Published var generating = false
    @Published var saving = false
    @Published var saved = false
    @Published var status = ""
    @Published var errorMessage: String?
    @Published var elapsed: Double?
    @Published var showSource = false
    @Published var calendars: [EKCalendar] = []
    @Published var selectedCalendarID = ""
    @Published var loadingCalendars = false
    @Published private(set) var hiddenCalendarIDs = Set(UserDefaults.standard.stringArray(forKey: "HiddenCalendarIDs") ?? [])
    let ai = LocalEventAI()
    let store = EKEventStore()
    private var generation: Task<Void, Never>?
    private var timeout: Task<Void, Never>?
    private var requestID = UUID()
    var dismiss: (() -> Void)?

    func refreshCalendars() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            calendars = []
            selectedCalendarID = ""
            return
        }
        calendars = store.calendars(for: .event).filter {
            isWritableICloudCalendar($0) && !hiddenCalendarIDs.contains($0.calendarIdentifier)
        }.sorted {
            calendarLabel($0).localizedCaseInsensitiveCompare(calendarLabel($1)) == .orderedAscending
        }
        let remembered = UserDefaults.standard.string(forKey: "SelectedCalendarID") ?? ""
        if calendars.contains(where: { $0.calendarIdentifier == selectedCalendarID }) { return }
        if calendars.contains(where: { $0.calendarIdentifier == remembered }) {
            selectedCalendarID = remembered
        } else {
            selectedCalendarID = ""
        }
        if !remembered.isEmpty && remembered != selectedCalendarID {
            errorMessage = "Your previously selected calendar is unavailable. Choose a calendar below."
        } else if calendars.isEmpty && hiddenCalendarIDs.isEmpty {
            errorMessage = "No writable iCloud calendars were found. Enable iCloud Calendar in System Settings and check Apple Calendar."
        }
    }

    func isWritableICloudCalendar(_ calendar: EKCalendar) -> Bool {
        guard let source = calendar.source else { return false }
        // EventKit exposes a source name and type, not a public account-provider ID.
        // Fail closed for unknown sources and read-only calendars.
        return CalendarDestinationPolicy.allows(sourceName: source.title,
                                                 isCalDAV: source.sourceType == .calDAV,
                                                 writable: calendar.allowsContentModifications)
    }

    func calendarLabel(_ calendar: EKCalendar) -> String {
        "\(calendar.title) — iCloud"
    }

    func chooseCalendar(_ identifier: String) {
        selectedCalendarID = identifier
        UserDefaults.standard.set(identifier, forKey: "SelectedCalendarID")
        errorMessage = nil
    }

    func hideCalendar(_ identifier: String) {
        guard !saving, !loadingCalendars,
              calendars.contains(where: { $0.calendarIdentifier == identifier }) else { return }
        hiddenCalendarIDs.insert(identifier)
        UserDefaults.standard.set(Array(hiddenCalendarIDs).sorted(), forKey: "HiddenCalendarIDs")
        if selectedCalendarID == identifier {
            selectedCalendarID = ""
            UserDefaults.standard.removeObject(forKey: "SelectedCalendarID")
        }
        errorMessage = nil
        refreshCalendars()
    }

    func showAllCalendars() {
        guard !saving, !loadingCalendars else { return }
        hiddenCalendarIDs.removeAll()
        UserDefaults.standard.removeObject(forKey: "HiddenCalendarIDs")
        errorMessage = nil
        refreshCalendars()
    }

    func setCalendarChecked(_ identifier: String, checked: Bool) {
        guard !saving, !loadingCalendars else { return }
        refreshCalendars()
        if checked {
            guard calendars.contains(where: { $0.calendarIdentifier == identifier }) else {
                errorMessage = "This calendar is unavailable. Refresh the list and choose another calendar."
                return
            }
            chooseCalendar(identifier)
        } else if selectedCalendarID == identifier {
            selectedCalendarID = ""
            UserDefaults.standard.removeObject(forKey: "SelectedCalendarID")
        }
    }

    func enableCalendarPicker() {
        guard !loadingCalendars, !saving else { return }
        loadingCalendars = true
        errorMessage = nil
        Task {
            defer { loadingCalendars = false }
            do {
                let granted: Bool
                if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
                    granted = true
                } else {
                    granted = try await store.requestFullAccessToEvents()
                }
                guard granted else {
                    errorMessage = "To list your iCloud calendars, allow Calendar access for iCalendify in System Settings → Privacy & Security → Calendars."
                    return
                }
                refreshCalendars()
            } catch {
                errorMessage = "Could not load calendars: \(error.localizedDescription)"
            }
        }
    }

    func begin(_ text: String) {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        stopGeneration()
        hasDraft = true
        saved = false
        errorMessage = nil
        refreshCalendars()
        elapsed = nil
        draft = NativeEventParser.draft(source: source)
        generateTitle()
    }

    func generateTitle() {
        stopGeneration()
        let source = draft.source
        elapsed = nil
        if let message = ai.unavailableMessage { status = message; return }
        guard source.count <= 8000 else {
            status = "Select a shorter passage (up to 8,000 characters) for AI, or enter the details below."
            return
        }
        generating = true
        status = "Writing a title on this Mac…"
        let id = UUID()
        requestID = id
        let started = Date()
        generation = Task { [weak self] in
            guard let self else { return }
            do {
                let event = try await ai.extract(source)
                guard !Task.isCancelled, requestID == id else { return }
                let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { draft.title = String(title.prefix(160)) }
                elapsed = Date().timeIntervalSince(started)
                status = "Title ready. Check the details before saving."
            } catch {
                guard !Task.isCancelled, requestID == id else { return }
                status = "Apple Intelligence could not generate a title. Edit the title or try again."
            }
            generating = false
            timeout?.cancel()
            generation = nil
        }
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(25)) } catch { return }
            guard let self, requestID == id, generating else { return }
            stopGeneration()
            status = "AI is taking longer than expected. You can edit the event now or try again."
        }
    }

    func stopGeneration() {
        requestID = UUID()
        generation?.cancel()
        generation = nil
        timeout?.cancel()
        timeout = nil
        generating = false
    }

    func editManually() {
        stopGeneration()
        status = "Enter the event details below."
    }

    func newEvent() {
        stopGeneration()
        hasDraft = false
        saved = false
        input = ""
        errorMessage = nil
    }

    func setAllDay(_ value: Bool) {
        let calendar = Calendar.current
        draft.allDay = value
        if value {
            draft.start = calendar.startOfDay(for: draft.start)
            draft.end = calendar.date(byAdding: .day, value: 1, to: draft.start)!
        } else {
            draft.start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: draft.start)!
            draft.end = draft.start.addingTimeInterval(3600)
        }
    }

    func changeStart(_ value: Date) {
        let duration = draft.end.timeIntervalSince(draft.start)
        draft.start = value
        if draft.allDay {
            draft.start = Calendar.current.startOfDay(for: value)
            draft.end = Calendar.current.date(byAdding: .day, value: max(1, Int((duration / 86400).rounded())), to: draft.start)!
        } else {
            draft.end = value.addingTimeInterval(max(60, duration))
        }
    }

    func save() {
        guard !saving, !saved, !generating, !loadingCalendars else { return }
        if let problem = draft.validationError { errorMessage = problem; return }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess, !selectedCalendarID.isEmpty else {
            errorMessage = "Choose an iCloud calendar before saving."
            return
        }
        saving = true
        errorMessage = nil
        // Snapshot the reviewed fields before any asynchronous system permission prompt.
        let reviewed = draft
        let chosenCalendarID = selectedCalendarID
        Task {
            do {
                guard !hiddenCalendarIDs.contains(chosenCalendarID),
                      let calendar = store.calendar(withIdentifier: chosenCalendarID), isWritableICloudCalendar(calendar) else {
                    errorMessage = "The selected iCloud calendar is no longer writable or available. Choose another iCloud calendar."
                    saving = false
                    return
                }
                let event = EKEvent(eventStore: store)
                event.calendar = calendar
                event.title = reviewed.title.trimmingCharacters(in: .whitespacesAndNewlines)
                event.startDate = reviewed.start
                event.endDate = reviewed.end
                event.isAllDay = reviewed.allDay
                event.timeZone = reviewed.allDay ? nil : .current
                event.location = reviewed.location.isEmpty ? nil : reviewed.location
                event.notes = "Original selected text:\n\n" + reviewed.source
                try store.save(event, span: .thisEvent, commit: true)
                if !chosenCalendarID.isEmpty {
                    UserDefaults.standard.set(chosenCalendarID, forKey: "SelectedCalendarID")
                }
                saved = true
                status = "Added to \(calendarLabel(calendar))."
            } catch {
                errorMessage = "Could not save the event: \(error.localizedDescription)"
            }
            saving = false
        }
    }
}

struct EventView: View {
    @ObservedObject var state: EventState

    private let accent = Color(red: 0.05, green: 0.48, blue: 0.43)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if state.saved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32, weight: .medium)).foregroundStyle(accent)
                } else {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().interpolation(.high).frame(width: 48, height: 48)
                        .accessibilityLabel("iCalendify")
                }
                Text(state.saved ? "Event added" : "Add to Calendar")
                    .font(.system(size: 23, weight: .semibold))
                Spacer()
            }
            if state.saved {
                Text(state.draft.title).font(.title3.weight(.medium))
                Text(state.status).foregroundStyle(.secondary)
                HStack {
                    Button("New Event") { state.newEvent() }
                    Spacer()
                    Button("Done") { state.dismiss?() }.keyboardShortcut(.defaultAction)
                }
            } else if state.hasDraft {
                editor
            } else {
                welcome
            }
            HStack(spacing: 5) {
                Image(systemName: "lock.shield")
                Text("AI runs on this Mac · Your choice of iCloud calendar")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(26)
        .frame(width: 540)
        .fixedSize(horizontal: true, vertical: true)
        .tint(accent)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlight text in another app, then right-click and choose Services → Add to Calendar with iCalendify.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Or paste the event details here:").font(.subheadline).foregroundStyle(.secondary)
            TextEditor(text: $state.input)
                .font(.body).frame(height: 110).padding(6)
                .background(.background).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                .accessibilityLabel("Event text")
            if let message = state.ai.unavailableMessage {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            calendarPicker
            if let error = state.errorMessage {
                Text(error).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Close") { state.dismiss?() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create Event") { state.begin(state.input) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(state.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 8) {
                if state.generating { ProgressView().controlSize(.small) }
                Text(state.status).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let elapsed = state.elapsed {
                    Text(String(format: "%.1f s", elapsed)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TITLE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("Event title", text: $state.draft.title).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Event title")
                }
                Toggle("All day", isOn: Binding(get: { state.draft.allDay }, set: state.setAllDay))
                    .toggleStyle(.checkbox)
                DatePicker("Starts", selection: Binding(get: { state.draft.start }, set: state.changeStart),
                           displayedComponents: state.draft.allDay ? [.date] : [.date, .hourAndMinute])
                DatePicker("Ends", selection: endBinding,
                           displayedComponents: state.draft.allDay ? [.date] : [.date, .hourAndMinute])
                if !state.draft.allDay {
                    Text(TimeZone.current.identifier).font(.caption).foregroundStyle(.secondary)
                }
                TextField("Location or meeting link (optional)", text: $state.draft.location)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Location")
            }.disabled(state.generating || state.saving)

            if !state.generating && !state.draft.notices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(state.draft.notices.enumerated()), id: \.offset) { _, notice in
                        Label(notice, systemImage: "info.circle")
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }
            DisclosureGroup("Original text", isExpanded: $state.showSource) {
                ScrollView { Text(state.draft.source).font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 100).padding(.top, 5)
            }.foregroundStyle(.secondary)
            calendarPicker
            if let error = state.errorMessage ?? state.draft.validationError {
                Text(error).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Cancel") { state.newEvent(); state.dismiss?() }.keyboardShortcut(.cancelAction)
                    .disabled(state.saving)
                if state.generating {
                    Button("Enter Manually") { state.editManually() }
                } else {
                    Button("Try AI Again") { state.generateTitle() }.disabled(state.saving)
                }
                Spacer()
                Button(state.saving ? "Saving…" : "Add to Calendar") { state.save() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(state.generating || state.saving || state.loadingCalendars || state.selectedCalendarID.isEmpty || state.draft.validationError != nil)
            }
        }
    }

    private var calendarPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("iCloud calendar").font(.callout.weight(.medium))
                Spacer()
                if state.loadingCalendars { ProgressView().controlSize(.small) }
                Button(state.calendars.isEmpty ? "Load calendars" : "Refresh") {
                    state.enableCalendarPicker()
                }
                .disabled(state.loadingCalendars || state.saving)
            }
            if !state.calendars.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(state.calendars, id: \.calendarIdentifier) { calendar in
                            Toggle(calendar.title, isOn: Binding(
                                get: { state.selectedCalendarID == calendar.calendarIdentifier },
                                set: { state.setCalendarChecked(calendar.calendarIdentifier, checked: $0) }))
                                .toggleStyle(.checkbox)
                                .disabled(state.loadingCalendars || state.saving)
                                .contextMenu {
                                    Button("Hide from list") { state.hideCalendar(calendar.calendarIdentifier) }
                                        .disabled(state.loadingCalendars || state.saving)
                                }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: min(CGFloat(state.calendars.count) * 28, 100))
                Text("Tick one · Your choice is remembered on this Mac")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(state.hiddenCalendarIDs.isEmpty
                     ? "Load calendars, allow Calendar access, then choose where to save."
                     : "No calendars are shown. Restore hidden calendars or refresh the list.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !state.hiddenCalendarIDs.isEmpty {
                Button("Show hidden calendars") { state.showAllCalendars() }
                    .font(.caption).disabled(state.loadingCalendars || state.saving)
            }
        }
    }

    private var endBinding: Binding<Date> {
        Binding(get: {
            state.draft.allDay ? Calendar.current.date(byAdding: .day, value: -1, to: state.draft.end)! : state.draft.end
        }, set: { value in
            state.draft.end = state.draft.allDay ? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: value))! : value
        })
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let state = EventState()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        state.dismiss = { [weak self] in self?.window?.close() }
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit iCalendify", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = appMenu; menu.addItem(appItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem(); editItem.submenu = editMenu; menu.addItem(editItem)
        NSApp.mainMenu = menu
        state.refreshCalendars()
        showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    @objc func addToCalendar(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error.pointee = "Select some event text first."
            return
        }
        guard !state.saving else {
            error.pointee = "Please finish saving the current event first."
            return
        }
        state.begin(text)
        showWindow()
    }

    func showWindow() {
        if window == nil {
            let hosting = NSHostingController(rootView: EventView(state: state))
            let panel = NSWindow(contentViewController: hosting)
            panel.title = "iCalendify"
            panel.styleMask = [.titled, .closable, .miniaturizable]
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.center()
            window = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { !state.saving }
    func windowWillClose(_ notification: Notification) { state.stopGeneration() }
}

@main
struct iCalendify {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
