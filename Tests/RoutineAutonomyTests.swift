import Foundation

@main struct RoutineAutonomyTests {
    static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            checks += 1
            if !condition() { fputs("FAIL: \(name)\n", stderr); exit(1) }
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 14))!
        let today = calendar.startOfDay(for: now)
        func row(_ offset: Int, _ minutes: Double = 60, _ drop: Double = 10) -> BatteryDay {
            BatteryDay(day: calendar.date(byAdding: .day, value: offset, to: today)!, minutes: minutes, drop: drop)
        }
        func forecast(_ days: [BatteryDay]) -> RoutineAutonomy { RoutineAutonomy(days: days, now: now, calendar: calendar) }
        check(forecast([]).estimate == nil, "No invented estimate without real data")
        check(forecast([row(0), row(-1)]).estimate == nil, "Two days do not establish a routine")
        check(forecast([row(0, 20), row(-1, 20), row(-2, 20)]).estimate == nil, "At least 90 observed minutes")
        check(forecast([row(0, 30, 1), row(-1, 30, 1), row(-2, 30, 1)]).estimate == nil, "Enough discharge required to resist rounding noise")
        let regular = forecast([row(0), row(-1), row(-2)])
        check(regular.estimate != nil && regular.observedDays == 3, "Three substantial observed days unlock the projection")
        let e = regular.estimate!
        check(abs(e.centralRate - 10) < 0.0001, "Ten battery points per hour implies ten hours from full")
        check(abs(e.lowerMinutes - 480) < 0.001 && abs(e.upperMinutes - 800) < 0.001, "Full 100 points used; reserve and current percentage are not deducted")
        check(e.confidence == .low, "Early routine explicitly has low confidence")
        let weighted = forecast([row(0, 240, 20), row(-1, 30, 10), row(-2, 30, 10)]).estimate!
        check(abs(weighted.centralRate - 8) < 0.001, "Long quiet days are weighted by exposure instead of equated with short busy days")
        let variable = forecast([row(0, 60, 2), row(-1, 60, 10), row(-2, 60, 18)]).estimate!
        check(variable.upperMinutes - variable.lowerMinutes > e.upperMinutes - e.lowerMinutes, "Changing daily consumption widens the range")
        let stable = forecast((0..<5).map { row(-$0) }).estimate!
        check(stable.confidence == .medium, "Five stable days and 300 minutes permit medium confidence")
        check(forecast((0..<7).map { row(-$0, 120, 20) }).estimate!.confidence == .medium, "Uncalibrated routine never claims high confidence")
        check(forecast([row(0), row(-1), row(-7), row(1)]).estimate == nil, "Old and future observations are excluded")
        check(forecast([row(0), row(-1), row(-2, 9, 1)]).estimate == nil, "Brief days do not establish a routine")
        check(forecast([row(0), row(-1), row(-2, .infinity), row(-3, 60, .nan), row(-4, -1), row(-5, 60, -1)]).estimate == nil, "Invalid measurements cannot unlock the estimate")
        check(forecast([row(0), row(0), row(-1)]).estimate == nil, "Repeated rows do not invent unique days")
        check(forecast([row(0, 60, 0), row(-1), row(-2)]).estimate!.centralRate < e.centralRate, "Observed zero-drop time contributes to the real daily mix")
        check(forecast([row(0, 600, 120), row(-1), row(-2)]).estimate != nil, "Daily usage may exceed 100 points after recharging")
        let ancient = forecast([row(-7), row(-8), row(-9)])
        check(ancient.estimate == nil && ancient.observedDays == 0, "Stale history returns to learning instead of forecasting indefinitely")
        print("PASS: \(checks) daily-routine autonomy checks")
    }
}
