# How Akku works

This is a description of the published implementation, not a certification of accuracy. User guides are available in all six languages from the [README](../README.md).

## Runtime forecasts

`AutomaticSessionTracker` records observed awake time on battery. It debounces external-power reconnection for sixty seconds, excludes sleep and gaps over ninety-five seconds, handles percentage rebounds, splits intervals across local midnight and resumes without inventing activity while the app was closed.

`RoutineAutonomy` uses seven calendar days, including today. Eligible days have at least ten observed minutes. A forecast requires three distinct eligible days, ninety minutes and five consumed percentage points. The central discharge rate is total drop divided by total time, rather than an unweighted average of days. Time with no measured drop contributes to the mix. Multiple charges can produce daily consumption above 100 points.

A minimum 25% rate margin is widened using day-to-day variation and percentage quantization, capped at 80%. The projected range spends 100 percentage points; the reserve is not deducted. Initial confidence is low; five stable days and at least 300 minutes may permit medium. High confidence is intentionally unavailable until empirical calibration exists. These are heuristic ranges, not calibrated probability intervals.

The separate activity/context engine still supports app-combination summaries and return-home advice. It uses discharge intervals, conditions and an initial adjustable baseline where data is sparse. Its reserve and baseline settings do not change the full-charge routine estimate. Existing manual-plan histories remain readable for migration; the current home screen has no manual activity/duration planner.

## Apps, conditions and energy

`NSWorkspace` supplies running applications and foreground changes. Aggregate foreground and open time are separate. No window titles, browser content, documents, messages, keystrokes or call contents are captured. An app's presence does not establish its exact activity.

Whole-Mac discharge can be associated with sustained combinations of apps, not attributed as exact energy to each app. Process CPU inspection uses native process information on demand, checks CPU-time conversion, and refers to the main process rather than all helpers. A 100% value means one CPU core. CPU, resident memory and battery percentages are not direct watt-hour measurements.

The activity/context engine considers external displays, low-power state and sustained intensive/thermal conditions. The daily-routine range instead reflects variation in observed daily consumption; it is not an instant simulation of new hardware or workload.

## Places

Core Location is requested about every five minutes while awake. Repeated failures back off to ten, twenty and thirty minutes. Sleep cancels pending requests. Location quality and freshness gate observations. Familiar-place suggestions require repeated visits; naming home/work is a user decision.

Departure detection requires a confirmed home observation followed by two suitable outside observations at least two minutes apart. Notification preferences are independent of recording. Silent departure notices have a cooldown and can be postponed. Detection latency and missing positions are expected.

MapKit displays 7/30-day charging, low-battery and use layers. Charging events require observed increase while charging; low means at most 10%, critical at most 3%. An observed 0% is not proof of shutdown. Low-battery patterns need repeated days and sufficient observed time; they do not predict a shutdown probability.

Manual places can be entered with coordinates; address search sends the query to Apple only after Search. A manually set current position remains in memory for thirty minutes, temporarily suspends automatic location, and is not used to claim automatic departure or learn visits.

Home distance is straight-line distance with uncertainty. Beyond five kilometres after accounting for uncertainty is described as far. Return advice needs travel/use assumptions and a reserve; it is not routing. Closed-Mac travel uses an explicit provisional assumption of two battery points per hour, not a measured sleep rate.

## Companion and overhead

Eight local contextual moods use battery, charging, hour, recent usage and permitted location. Recent-use timing relies on the system idle counter without collecting input; five idle minutes or sleep starts a new usage period. Break suggestions are approximate and can be silenced.

Animations run at eight frames per second for about two seconds, followed by eighteen seconds without animation callbacks. Appearance and mood changes restart a short burst. Hidden windows, reduced motion, Low Power Mode and Emergency mode pause animation. This is a policy to limit work, not a measurement of total app energy.

The main observation cadence is sixty seconds in the background and thirty while visible, with OS timer tolerance. Low Power/Emergency retain the slower cadence; sleep cancels the timer. Checkpoints batch writes approximately every five minutes, while important lifecycle events may force persistence. Unchanged data avoids repeat writes. Map/CPU work is driven by visible needs.

Emergency mode attempts supported brightness changes and tracks undo state. System low-power and synchronization controls remain manual. App termination requests require confirmation and use normal quit; they never force termination. An abrupt crash may prevent brightness restoration.

## Storage and permissions

Data lives in `~/Library/Application Support/BatteryTrip`, normally with directory mode 0700 and file mode 0600. Preferences retain `com.batterytrip.mac` for migration. There is no developer backend or analytics account.

Retention is bounded: up to 400 discharge intervals over sixty days, 400 charge intervals over thirty days, 400 automatic sessions over sixty days, prior comparison outcomes, thirty familiar places and roughly eleven days of compact battery-panel observations. Learning archives are tied to hardware identity; do not move personal learning files between Macs to claim cross-model validation.

Location records include coordinates and aggregate visits, not a continuous route. Maps, searches and macOS location can use Apple's services. Battery export omits coordinates and place associations, but includes app identifiers and battery/usage observations. Users should review exports before disclosure. Erasing places and erasing learning are separate controls.

## Building and maintaining

`build.sh` compiles all `Sources/*.swift`, produces a universal binary, creates the icon/resources and signs locally. Current product support is limited to MacBook Air/Pro M1–M5 regardless of the available binary slices. `notarize.sh` requires the maintainer's own signing identity and Keychain profile.

`Translations.json` contains French, Simplified Chinese, German and Brazilian Portuguese values. English/Spanish templates remain in Swift. `LocalizedPhrase` separates placeholders from values, preserving user names without recursively substituting placeholder-like text. Run `python3 Scripts/check_localization.py --generate` after catalog changes; `test.sh` audits coverage and generated-source consistency.

Main modules: `System` coordination; `AutomaticSessions` routine/session models; `BatteryHistory`/`BatteryPanel` history; `Learning`/`Journey` contextual estimates and migration; `NativeApps` app observation; `Places`/`PlaceHistory` aggregation; `Integrations` platform permissions; `EnergyMap` map; `Companion`/`Buddy` character; `EnergyPolicy` scheduling; `Views`/`RoutineAutonomyCard` interface. Everything can be inspected in this repository.
