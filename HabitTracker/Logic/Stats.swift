import Foundation

/// Pure, UI-free statistics for a habit. Kept separate from views so it can be
/// unit-tested directly. The low-level functions work on a `Set<Date>` of
/// completed (goal-met) days, normalized to start-of-day.
enum HabitStats {

    /// The set of days on which the habit's goal was met.
    static func completedDays(for habit: Habit) -> Set<Date> {
        let calendar = Calendar.current
        var days: Set<Date> = []
        for entry in habit.entries where entry.amount >= habit.goalAmount {
            days.insert(calendar.startOfDay(for: entry.date))
        }
        return days
    }

    // MARK: Current streak

    static func currentStreak(for habit: Habit, asOf today: Date = Date()) -> Int {
        currentStreak(completedDays: completedDays(for: habit), asOf: today)
    }

    /// Consecutive completed days ending today. If today isn't completed yet,
    /// the streak is measured through yesterday (so an unfinished today doesn't
    /// instantly zero out the streak).
    static func currentStreak(completedDays: Set<Date>, asOf today: Date = Date()) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: today)

        if !completedDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while completedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: Longest streak

    static func longestStreak(for habit: Habit) -> Int {
        longestStreak(completedDays: completedDays(for: habit))
    }

    static func longestStreak(completedDays: Set<Date>) -> Int {
        guard !completedDays.isEmpty else { return 0 }
        let calendar = Calendar.current
        let sorted = completedDays.sorted()

        var longest = 1
        var run = 1
        for i in 1..<sorted.count {
            if let nextOfPrev = calendar.date(byAdding: .day, value: 1, to: sorted[i - 1]),
               calendar.isDate(nextOfPrev, inSameDayAs: sorted[i]) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        return longest
    }

    // MARK: Totals & rate

    /// Total number of days the goal was met.
    static func totalCompleted(for habit: Habit) -> Int {
        completedDays(for: habit).count
    }

    /// Fraction (0...1) of days completed since the habit's first activity.
    static func completionRate(for habit: Habit, asOf today: Date = Date()) -> Double {
        let calendar = Calendar.current
        let completed = completedDays(for: habit)

        let entryDays = habit.entries.map { calendar.startOfDay(for: $0.date) }
        guard let earliest = (completed.union(entryDays)).min() else { return 0 }

        let start = min(earliest, calendar.startOfDay(for: habit.createdAt))
        let end = calendar.startOfDay(for: today)
        let span = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        guard span > 0 else { return 0 }
        return Double(completed.count) / Double(span)
    }
}
