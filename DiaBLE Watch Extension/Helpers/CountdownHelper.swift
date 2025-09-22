import Foundation

func calculateReadingCountdown(lastConnectionDate: Date, readingIntervalMinutes: Int, now: Date = Date()) -> Int {
    guard lastConnectionDate != .distantPast else {
        return 0
    }
    return readingIntervalMinutes * 60 - Int(now.timeIntervalSince(lastConnectionDate))
}
