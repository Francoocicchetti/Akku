# Helping Akku improve

The maintainer is a Spanish speaker, not a professional programmer. Clear explanations and small, reviewable changes help more than unexplained rewrites. This is a personal experimental project; there is no promised support response time.

You can help without writing code: report a confusing screen, describe battery behavior, suggest a better translation, test your own MacBook or propose a useful feature. All six app languages are welcome. Start with [FEEDBACK.md](FEEDBACK.md) or the language-specific issue forms.

For code contributions, describe the problem, the change and how you verified it. Preserve existing data migrations and privacy controls. Do not introduce telemetry, remote services or new permission requests silently. Changes to background polling or animation should explain their cost. Avoid claiming per-app energy from CPU, exact call detection, instant geofencing or certified battery savings.

Run `./test.sh` and `./build.sh "$PWD/dist"` on macOS when relevant. Tests use isolated fixtures; do not commit personal archives, real coordinates, screenshots of private places, exports, credentials or signing identities. Hardware recognition tests do not replace physical sessions on actual M1–M5 MacBooks.

For translations, edit `Translations.json`, preserve placeholders such as `{0}`, and run `python3 Scripts/check_localization.py --generate`. English and Spanish source templates are in `Sources`. Update the matching language README when user-facing behavior changes. Say which language you know and why your wording is clearer; native-speaker review is welcome.

There is no selected open-source license yet. This contribution guide does not introduce a license or a contributor agreement. Discuss reuse/distribution expectations with the maintainer before substantial contributions.
