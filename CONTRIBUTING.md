# Contributing to iCalendify

Small, focused improvements are welcome. Open an issue before a substantial change so the intended behavior can be discussed.

1. Fork the repository and create a branch.
2. Use an Apple silicon Mac running macOS 26+ with a compatible Swift toolchain.
3. Run `bash build.sh` and `bash test.sh`.
4. For title-generation changes, also run `bash test.sh --ai` with Apple Intelligence enabled and inspect the wording.
5. Explain the behavior change and the checks you ran in your pull request.

Keep selected text local, preserve the preview-before-save flow, and never silently choose a different calendar. Any expansion of calendar access or networking should be discussed explicitly.

Use synthetic events in tests. Never include personal calendar identifiers, event exports, credentials, signing certificates, or screenshots with private information. Tests should not create real calendar events automatically.

The icon is drawn with AppKit. To regenerate its PNG and ICNS assets, run `xcrun swift scripts/make-icon.swift` from the repository root.

Run `bash package.sh` to build an unnotarized disk image and checksum in `dist/`. A pushed `vX.Y.Z` tag matching the version in `Info.plist` runs the tests, packages the app on GitHub, and publishes the download with `docs/RELEASE_NOTES.md`.

By contributing, you agree that your contribution is provided under the project's MIT license.
