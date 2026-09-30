<p align="center"><img src="Assets/AkkuLogo.png" width="160" alt="Akku, the green battery monkey"></p>

# Akku

**Your battery, understood through your everyday routine.** An experimental native macOS companion for MacBook Air and Pro with Apple Silicon M1–M5.

[English](README.md) · [Español](docs/i18n/README.es.md) · [Français](docs/i18n/README.fr.md) · [简体中文](docs/i18n/README.zh-Hans.md) · [Deutsch](docs/i18n/README.de.md) · [Português (Brasil)](docs/i18n/README.pt-BR.md)

[Download](https://github.com/Francoocicchetti/Akku/releases) · [Feedback & ideas](https://github.com/Francoocicchetti/Akku/discussions) · [Report a problem](https://github.com/Francoocicchetti/Akku/issues/new/choose)

## Why I made Akku

I'm a Spanish speaker, and I'm not a programmer. I made Akku with help from AI tools because I wanted to take better care of my MacBook and understand its battery: how long it lasts with my routine, where I usually charge, and when I should take the charger with me.

This started as something for the health of my own MacBook. I wanted the app to learn from everyday use instead of making me enter everything I do. Akku is also the little monkey who keeps you company: energetic, sleepy, hungry for electricity, or quietly reminding you to take a break.

**This is a personal, experimental project. It can contain bugs, inaccurate estimates and unfinished behavior.** I don't claim professional development experience or that every MacBook has been tested. I'm publishing it so others can try it, inspect it and help improve it. It does not repair a battery or prove that its lifespan will increase.

I'm a native Spanish speaker, so **some translations may be awkward or wrong**, including the English documentation. Corrections are very welcome. You can leave feedback in any of the six supported languages.

## Compatibility and languages

- This release is intended **only for MacBook Air and MacBook Pro with M1, M2, M3, M4 or M5**, including applicable Pro/Max chip variants.
- Physical testing so far: **one MacBook Air M5**. Recognizing a model is not the same as validating every configuration.
- macOS 13 or later, subject to the minimum macOS version required by your particular Mac. Older supported macOS versions still need real-device testing.
- Intel Macs, desktop Macs, MacBook Neo, Windows and Linux are outside the current support scope. The build script can produce an Intel slice; that is not a support claim.
- English is the default on a fresh installation. Switch immediately to Spanish, French, Simplified Chinese, German or Brazilian Portuguese from the header or Settings. Your choice is saved.

## What Akku does

### A full charge, your routine

Akku estimates **how long a charge from 100% to 0% would last with the mix of uses observed during the last seven days**. There is no activity selector or manual duration in the main screen.

It uses actual percentage drop divided by observed awake time on battery. Charging, sleep and missing observations are excluded. This particular estimate does **not** subtract a safety reserve and does not use your current battery percentage as a full charge.

A first estimate needs three observed days, at least ten minutes on each, ninety minutes in total and five percentage points consumed. Before that, Akku shows learning progress instead of inventing a personal runtime. It presents a range and confidence; variation between days widens the range. Routine confidence is capped at medium until real-world calibration improves. A different workload, accessories or conditions can change the outcome.

### Automatic recording and useful history

Unplugging starts a session automatically. Opening Akku while already on battery starts observing from that moment. A confirmed departure from home can also begin a session. There is no scan or start button. Being connected while optimized charging is paused is not treated as unplugging.

Sleep and gaps are excluded; waking resumes observation. A stable connection for one minute ends the session. Akku must be running to learn; Launch at login is optional. Turning off learning pauses recording.

Statistics includes weekly use, sessions, consumed battery points, and time at home, away or with an unknown location. The battery panel offers **24 hours and 10 days**, battery level, charging/connection periods, observed screen-on time and interval details. Missing history stays visibly missing. Screen-on time is not proof of attention; battery points can exceed 100 across multiple recharges.

### Real apps and combinations

Akku uses native macOS app information to show running apps, icons and foreground use: Safari, FaceTime, ChatGPT, WhatsApp and other normal applications. Open time and foreground time are shown separately, with daily and place summaries.

It can learn whole-Mac consumption while combinations of apps are open. **CPU is not exact energy per app**, and foreground presence does not prove that a call is active. Websites inside Safari remain Safari. Akku does not read messages, documents, browser tabs, screen content or keystrokes. Background calls and reading without interaction may be underestimated.

### Places, map and getting home

An interactive Apple MapKit map shows familiar places, observed charging, low-battery events and use patterns over 7 or 30 days. Select a place to inspect observed apps and battery history. Suggestions for home/work need repeated observations; you confirm their meaning.

Automatic location requires macOS permission and can be disabled. Battery learning still works without it. You can enter a place or a current location manually; a manual current position lasts thirty minutes and is never presented as a detected departure. Address search uses Apple Maps when you press Search.

Akku can quietly ask “Heading out?” after a confirmed change of location. Detection is approximate, not instantaneous. Distance to home is **straight-line distance, not a route or travel time**. Return advice combines available battery, a reserve and the return/use durations you provide. It cannot guarantee you will make it home without charging. This is not Find My and cannot remotely locate a powered-off computer.

### Akku, your companion

The monkey has eight contextual states: ready, full, charging, low, exhausted, break time, evening and away. “Feed Akku” means connecting your real charger. Time, charge, recent computer use and allowed location guide the messages; there is no omniscient assistant or remote AI service.

Animations start when Akku appears or changes mood, then run in brief bursts. They stop when hidden, in Low Power Mode, Emergency mode or Reduce Motion. Gentle break suggestions remain inside the app and can be silenced; they are approximate reminders, not health monitoring.

### Emergency mode and low overhead

Emergency mode attempts to lower brightness on compatible displays, reduces Akku's own polling and explains what was applied. It provides an undo action. Low Power Mode and other apps' synchronization settings require manual action. Closing another app requests a normal quit with confirmation; it is not forced and may interrupt a call or upload. Reopening does not recover unsaved work.

There is no guaranteed extra hour. Ordinary observation runs about once a minute in the background, or every thirty seconds while visible. Sleep stops the timer. Writes are batched, CPU inspection is demand-driven, and failed location requests back off. Animations use brief eight-frame-per-second bursts rather than a continuous animation loop. **Low overhead is a design goal, not zero battery use or a benchmark for every Mac.**

## Privacy and permissions

There is no Akku account, analytics service or developer-operated backend. History stays in `~/Library/Application Support/BatteryTrip`; the old folder/bundle identity is retained to preserve existing users' data.

Local records include battery observations, app identifiers and usage, familiar-place coordinates and aggregated visits. A continuous route is not stored. Map tiles, address searches and macOS location services can communicate with Apple. Denying location disables location-dependent features, not battery learning.

You can erase learning in Settings and erase places in Places. Exports include battery observations and app identifiers, but omit coordinates and place associations. **Review and redact exports before sharing them publicly.** Do not post your home address, location screenshots or personal usage files in an issue.

## Install or build

Download the ZIP from [Releases](https://github.com/Francoocicchetti/Akku/releases), unzip it, move `Akku.app` to Applications and open it. Quit an older copy before replacing it. Closing the window leaves the menu-bar app running. Existing preferences and history are preserved; do not run old and new copies together.

The preview has a **local ad-hoc signature, not an Apple Developer ID signature or notarization**. macOS may warn or refuse to open it. No system-security disabling is required by this project. Building from source is available for inspection and testing; broader distribution signing remains pending.

On a Mac with Python 3, Xcode/Command Line Tools, a suitable macOS SDK and Swift 5.9 or newer:

```sh
./test.sh
./build.sh "$PWD/dist"
```

No third-party package dependencies are required. The script assembles and signs an app bundle. `notarize.sh` is for maintainers who already have their own Developer ID certificate and Keychain notary profile; no credentials are included here.

## Feedback and contributing

Please use [Discussions](https://github.com/Francoocicchetti/Akku/discussions) for experiences, ideas and questions, and the [language-specific issue forms](https://github.com/Francoocicchetti/Akku/issues/new/choose) for bugs, battery behavior and translation corrections. Spanish is especially welcome; English, French, Chinese, German and Portuguese are welcome too.

Useful details: MacBook model/chip, macOS version, Akku version/language, steps to reproduce, expected versus actual behavior, and whether the charger or Low Power Mode was active. For a translation, include the screen, current text and suggested wording. Share only redacted screenshots or exports.

See [Feedback](FEEDBACK.md), [Contributing](CONTRIBUTING.md), [technical details](docs/TECHNICAL.md), [validation and limitations](docs/VALIDATION.md) and [release notes](CHANGELOG.md). Automated checks do not establish safety, prediction accuracy or energy savings on every model. No open-source license has been selected yet; this repository does not declare an MIT/Apache or other license grant.
