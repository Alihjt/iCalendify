# Security

This is an early release. Downloads use an ad-hoc signature, not an Apple Developer ID, and are not notarized by Apple. Fixes target the latest code on `main`; older versions do not have a separate maintenance policy.

Do not publish credentials, private event text, calendar identifiers, or exploit details in a public issue. Use the repository's **Security → Report a vulnerability** option when available. If it is unavailable, open a minimal issue asking the maintainer for a private reporting channel without including sensitive details.

The intended boundaries are local AI processing, explicit user review before each save, and writable iCloud destinations only. Unexpected network transmission or saving without review should be treated as a security issue.
