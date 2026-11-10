<div align="center">

# iCalendify

**Turn selected text into an iCloud calendar event.**

A small native Mac app with on-device AI titles and a preview you control.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-111827?logo=apple&logoColor=white)
![Apple silicon](https://img.shields.io/badge/Apple_silicon-required-0f766e)
![License: MIT](https://img.shields.io/badge/License-MIT-2563eb)

**Select text → Right-click → Review → Save**

[Get started](#get-started) · [How it works](#how-it-works) · [Privacy](#privacy) · [Troubleshooting](#troubleshooting)

</div>

---

An invitation in an email. A workshop on a web page. A plan in a message.
iCalendify turns the text you select into an editable event, so you spend less time copying between apps.

**Early release — v0.1.0.** Download the app from GitHub Releases or build it yourself. The download is not Developer ID signed or notarized by Apple; this is not an App Store release.

## What you can do

- **Use a right-click action:** Services → Add to Calendar with iCalendify.
- **Generate a short title in English** using Apple Intelligence on your Mac.
- **Review dates, times, all-day status, and location** before saving.
- **Choose any writable iCloud calendar** available in Apple Calendar. Tick one checkbox; your choice is remembered locally.
- **Edit everything manually** if AI is unavailable or the result needs correcting.
- **Close it when you're finished.** No login item, background helper, or separate model server.

Clicking **Try AI Again** regenerates only the title. It preserves your edited date, time, location, and selected calendar.

## Requirements

| Requirement | Details |
| --- | --- |
| Mac | Apple silicon (M-series) |
| Operating system | macOS 26 or later |
| Calendar | iCloud Calendar enabled, with at least one writable calendar in Apple Calendar |
| AI titles | Apple Intelligence enabled and its on-device model downloaded by macOS |
| Building | Xcode Command Line Tools with the macOS 26 SDK or newer, or a compatible full Xcode installation |

AI is optional for manual entry. The current build targets Apple silicon only. You do not need an AI API key, subscription, Python environment, or third-party Swift packages.

## Get started

1. [Download the latest release](https://github.com/Alihjt/iCalendify/releases/latest). Choose the **`.dmg`** file under **Assets**.
2. Open it and drag **iCalendify** into **Applications**.
3. Open iCalendify from Applications. No Xcode or Terminal is required.

This download is not notarized by Apple. If macOS blocks it and you trust the download, try opening the app, then go to **System Settings → Privacy & Security → Open Anyway**. [Read Apple's explanation](https://support.apple.com/102445). Do not disable Gatekeeper system-wide.

To update, quit iCalendify and replace the older app in Applications. If you previously installed from source into `~/Applications`, move that older copy to Trash to avoid duplicate Services. Your preferences are stored separately from the app.

### Choose your calendar

Click **Load calendars** and allow Calendar access when macOS asks. Then tick the iCloud calendar you want to use. Calendar Full Access is required to list calendars; macOS does not offer an iCloud-only permission. iCalendify itself filters the list to writable iCloud calendars and does not fetch your existing events.

To simplify the list, right-click a calendar and choose **Hide from list**. This only hides it in iCalendify on this Mac; it does not delete or change the calendar. Click **Show hidden calendars** to restore the full list.

## Build from source

### 1. Install Apple's developer tools

If you do not already have them:

```sh
xcode-select --install
```

Use a toolchain that includes the macOS 26 SDK or newer. Check the selected SDK with `xcrun --sdk macosx --show-sdk-version`.

### 2. Download and build

```sh
git clone https://github.com/Alihjt/iCalendify.git
cd iCalendify
bash build.sh
bash test.sh
```

The build creates `build/iCalendify.app` and signs it locally with an ad-hoc signature. It does not use a developer certificate or notarization credentials.

### 3. Install and open

```sh
bash install.sh
```

This copies the app to `~/Applications/iCalendify.app`, registers its macOS Service, and opens it. The installer refuses to overwrite an existing copy. To update, quit the app, move the older bundle aside, and run the installer again.

## How to use it

1. Highlight event details in an app that supports macOS text Services.
2. Right-click and select **Services → Add to Calendar with iCalendify**.
3. Review the English title or edit it yourself.
4. Check the **year**, date, time, duration, location, and calendar. Edit anything that is wrong.
5. Click **Add to Calendar**. Click **Done** to quit afterward.

You can also open iCalendify and paste text directly.

Try a fictional example:

```text
Project planning meeting on 18 November 2027 at 2 pm for one hour.
Location: Meeting room A
```

No event is saved until you click **Add to Calendar**. The original selected text is included in the saved event's notes, so review it before saving to a shared calendar.

## How it works

| Part | Implementation |
| --- | --- |
| Right-click action | Native macOS Services |
| Event title | Apple's on-device `SystemLanguageModel.default`, via Foundation Models |
| Dates and locations | macOS data detectors, with additional English/German checks |
| Calendar access | EventKit |
| Interface | SwiftUI hosted in AppKit |

The app does not bundle or download its own language model. macOS supplies and updates the Apple Intelligence model. Each title request creates a short-lived session; there is no prewarming or retained AI session while the app is idle.

Closing the window, **Cancel**, or **Done** quits the app. Apple manages the shared model's memory independently and may cache model weights afterward; the app cannot force that system cache to unload.

## Privacy

- **Title generation happens on-device.** iCalendify makes no cloud AI requests and has no analytics, telemetry, or account system.
- **You choose the input.** It receives selected text through a Service or text you paste into its window. It does not automatically inspect the general clipboard.
- **Preferences stay local.** The chosen and hidden calendar identifiers are stored in app preferences. Unsaved drafts are not persisted by the app.
- **Saving uses iCloud.** The event, its location, and the original text in its notes sync through your chosen iCloud calendar. Shared-calendar participants may be able to see them.
- **Calendar names are discovered at runtime.** No account, personal calendar names, device identifiers, credentials, or user-specific paths are shipped in the source.

The app's MIT license covers its source code, not Apple's frameworks or model weights.

## Limitations

- Only writable iCloud calendars are supported. Google, Exchange, read-only calendars, and local “On My Mac” calendars are excluded.
- EventKit exposes a source name and type, not a public iCloud-provider identifier. The app accepts writable CalDAV sources named `iCloud` (case-insensitive). A renamed or differently localized source may not appear.
- AI titles are generated in English. Date recognition depends on macOS and your region settings; the extra checks focus on English and German.
- Dates without a year, numeric dates, relative dates, and multiple dates can be ambiguous. Always check the preview. A missing date produces a visible placeholder; a missing timed duration defaults to one hour.
- AI titles can be wrong. They are editable, and an AI failure does not prevent manual entry.
- Text over 8,000 characters skips AI generation. Requests time out after approximately 25 seconds; speed varies with hardware and model availability.
- The app creates one event at a time. It does not manage recurring events, reminders, attendees, or existing events.
- macOS and the host app decide where Services appear. iCalendify cannot force its action into every app's main right-click menu.

## Troubleshooting

**The right-click action is missing**

Open iCalendify once. In **System Settings → Keyboard → Keyboard Shortcuts → Services → Text**, enable **Add to Calendar with iCalendify**. Restart the app where you are selecting text if its menu has not refreshed. Some apps do not support text Services; paste into iCalendify instead.

**No calendars appear**

Check that iCloud Calendar is enabled and your calendars are writable in Apple Calendar. Click **Load calendars** or **Refresh**. Check **System Settings → Privacy & Security → Calendars** for iCalendify's permission. Locally rebuilt apps may need permission again after updates.

**AI is unavailable or slow**

Check **System Settings → Apple Intelligence & Siri**. macOS may still be downloading or preparing its model. Use **Enter Manually**, or edit the preview and save without AI.

**The event seems to be missing**

Search for its title in Apple Calendar. Check the selected calendar, year, date, timezone, and whether that calendar is visible. iCloud sync can take time.

**The build fails**

Check `xcrun swiftc --version` and `xcrun --sdk macosx --show-sdk-version`. An older selected Xcode or Command Line Tools installation may not include Foundation Models.

## Development

```sh
bash build.sh       # Build and verify the app's local signature
bash test.sh        # Calendar eligibility, date parsing, DST, and validation tests
bash test.sh --ai   # Also run on-device English title probes
bash package.sh     # Build an unnotarized disk image and checksum in dist/
```

The core tests use a fixed timezone and synthetic examples. They do not access your calendars or require Apple Intelligence. The optional AI probes require an available local model and may vary between OS/model versions. GitHub Actions builds the app and runs core tests; it does not run AI or save calendar events.

```text
Sources/
  App.swift           App UI, Services, and EventKit saving
  AI.swift            Request-scoped local title generation
  Core.swift          Draft, validation, and calendar eligibility
  DateDetection.swift Native date and location parsing
Tests/                Synthetic tests and optional manual probes
```

See [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidance and [SECURITY.md](../SECURITY.md) for security reporting. Please use fictional examples in issues and screenshots.

## Uninstall

Quit iCalendify and move it from Applications to Trash. Source installations default to `~/Applications/iCalendify.app`. No background service or login item needs removing. Events already saved to iCloud remain in your calendar.

## License

[MIT](../LICENSE) © 2026 iCalendify contributors.

iCalendify is an independent project, not affiliated with or endorsed by Apple. Apple Intelligence, iCloud, and macOS are Apple trademarks.
