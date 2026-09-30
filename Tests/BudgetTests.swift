import Foundation

@main
struct BudgetTests {
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { fputs("FAIL: \(message)\n", stderr); exit(1) }
        }
        let b = Budget(batteryPercent: 45, baselineHours: 10, reservePercent: 15)
        check(abs(b.minutes(for: .browsing) - 180) < 0.001, "45% battery minus 15% reserve gives 3h browsing")
        check(abs(b.minutes(for: .reading) - 300) < 0.001, "PDF multiplier")
        check(abs(b.minutes(for: .meeting) - 94.736842) < 0.001, "Video call multiplier")
        let mixed = [TripItem(activity: .browsing, minutes: 120), TripItem(activity: .meeting, minutes: 60)]
        check(abs(b.cost(of: mixed) - 39) < 0.001, "Mixed trip cost sums sequential activities")
        check(!b.fits(mixed), "Trip violates reserve despite having enough raw battery")
        check(abs(b.remaining(after: mixed) - 6) < 0.001, "Remaining battery is not usable battery")
        check(b.fits([TripItem(activity: .browsing, minutes: 180)]), "Exact reserve boundary fits")
        check(!b.fits([TripItem(activity: .browsing, minutes: 181)]), "One minute beyond budget does not fit")
        check(!b.fits([]), "Empty trip is not a successful plan")
        check(Budget(batteryPercent: 10, baselineHours: 10, reservePercent: 15).minutes(for: .reading) == 0, "Battery below reserve never returns negative time")
        check(Budget(batteryPercent: 0, baselineHours: 10, reservePercent: 15).minutes(for: .browsing) == 0, "Empty battery")
        check(Budget(batteryPercent: 100, baselineHours: 0, reservePercent: 15).minutes(for: .browsing) == 0, "Invalid baseline")
        check(duration(199) == "3h 15m", "Display rounds down, not up")
        check(duration(1) == "<5m", "Very small positive estimate")
        check(duration(-10) == "0m", "Negative duration")
        check(duration(.infinity) == "0m", "Non-finite duration")
        for activity in Activity.allCases {
            check(activity.name(.en) != activity.name(.es), "Localized activity: \(activity)")
            for percent in stride(from: 15.0, through: 100.0, by: 5) {
                let budget = Budget(batteryPercent: percent, baselineHours: 10, reservePercent: 15)
                let minutes = Int(floor(budget.minutes(for: activity)))
                let trip = [TripItem(activity: activity, minutes: minutes)]
                check(budget.fits(trip), "Estimate / cost inverse: \(activity), \(percent)%")
                check(budget.remaining(after: trip) >= 15 - 0.000001, "Reserve preserved")
            }
        }
        let original = [TripItem(activity: .reading, minutes: 45)]
        let data = try! JSONEncoder().encode(original)
        check(try! JSONDecoder().decode([TripItem].self, from: data) == original, "Saved trip round-trip")
        print("PASS: \(checks) budget, boundary, localization and persistence checks")
    }
}
