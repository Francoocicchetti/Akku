import Foundation
@main struct EnergyPolicyTests {
    static func main() {
        var checks = 0
        func check(_ value: @autoclosure () -> Bool, _ name: String) {
            checks += 1; if !value() { fputs("FAIL: \(name)\n", stderr); exit(1) }
        }
        check(EnergyPolicy.interval(visible: false, learning: true, lowPower: false, emergency: false, sleeping: false) == 60, "Background observation once per minute")
        check(EnergyPolicy.interval(visible: true, learning: true, lowPower: false, emergency: false, sleeping: false) == 30, "Visible view remains responsive")
        check(EnergyPolicy.interval(visible: true, learning: true, lowPower: true, emergency: false, sleeping: false) == 60, "Low power uses reduced cadence even when visible")
        check(EnergyPolicy.interval(visible: true, learning: true, lowPower: false, emergency: true, sleeping: false) == 60, "Emergency retains lower cadence")
        check(EnergyPolicy.interval(visible: false, learning: false, lowPower: false, emergency: false, sleeping: false) == 300, "Paused learning doesn't keep an unnecessary sampling cadence")
        check(EnergyPolicy.interval(visible: true, learning: true, lowPower: false, emergency: false, sleeping: true) == nil, "Sleep invalidates timer completely")
        check(EnergyPolicy.tolerance(for: 60) == 10, "OS may coalesce periodic work")
        check(60 + EnergyPolicy.tolerance(for: 60) < 95, "Learning gap guard still accepts ordinary timer jitter")
        var checkpoint = CheckpointGate()
        check(checkpoint.due("history", uptime: 0), "First checkpoint available")
        checkpoint.committed("history", uptime: 0)
        check(!checkpoint.due("history", uptime: 60), "One-minute observations do not write each time")
        check(!checkpoint.due("history", uptime: 299), "Checkpoint batches for five minutes")
        check(checkpoint.due("history", uptime: 300), "Checkpoint due after five minutes")
        check(checkpoint.due("history", uptime: 60, force: true), "Power/sleep/quit/critical events can force durable state")
        check(checkpoint.due("other", uptime: 60), "Archives retain independent checkpoints")
        checkpoint.committed("history", uptime: 300)
        check(checkpoint.due("history", uptime: 100), "Monotonic reset doesn't suppress saving indefinitely")
        checkpoint.reset()
        check(checkpoint.due("history", uptime: 301), "Erase resets checkpoint state")
        var retry = LocationBackoff()
        check(retry.interval == 300, "Successful location defaults to five minutes")
        retry.failed(); check(retry.interval == 600, "First failure reduces requests")
        retry.failed(); check(retry.interval == 1200, "Repeated failures back off")
        for _ in 0..<20 { retry.failed() }
        check(retry.interval == 1800 && retry.failures == 3, "Retry work is bounded")
        retry.succeeded(); check(retry.interval == 300, "Recovery restores normal location cadence")
        var date = Date(timeIntervalSinceReferenceDate: 0)
        var frames = 0
        while date.timeIntervalSinceReferenceDate < 60 {
            frames += 1; let next = EnergyPolicy.nextAnimationDate(after: date)
            check(next > date, "Animation schedule always advances")
            date = next
        }
        check(frames <= 55, "Burst schedule avoids continuous display-link animation")
        let idle = Date(timeIntervalSinceReferenceDate: 7)
        check(EnergyPolicy.nextAnimationDate(after: idle).timeIntervalSinceReferenceDate == 20, "No callbacks during the long rest phase")
        let appearance = Date(timeIntervalSinceReferenceDate: 137)
        check(EnergyPolicy.nextAnimationDate(after: appearance, origin: appearance).timeIntervalSince(appearance) == 0.125, "Opening during a global rest phase immediately starts the animation")
        check(EnergyPolicy.animationPhase(at: appearance.addingTimeInterval(0.875), origin: appearance) == 0.875, "Blink occurs inside the visible animation burst")
        check(EnergyPolicy.nextAnimationDate(after: appearance.addingTimeInterval(2), origin: appearance) == appearance.addingTimeInterval(20), "Opening burst still sleeps for eighteen seconds")
        check(EnergyPolicy.animationPhase(at: appearance.addingTimeInterval(20), origin: appearance) == 0, "Periodic burst returns to a neutral pose")
        let changedMood = appearance.addingTimeInterval(9)
        check(EnergyPolicy.nextAnimationDate(after: changedMood, origin: changedMood).timeIntervalSince(changedMood) == 0.125, "Mood changes immediately restart the short burst")
        var writes = 0
        var gate = CheckpointGate()
        for second in stride(from: 0, through: 3600, by: 60) {
            if gate.due("history", uptime: Double(second)) { writes += 1; gate.committed("history", uptime: Double(second)) }
        }
        check(writes == 13, "One-hour workload checkpoints 13 times rather than 121 every-30s saves")
        print("PASS: \(checks) timer/sleep policy, checkpoint batching, location backoff and sparse animation checks; \(frames) animation frames/minute")
    }
}
