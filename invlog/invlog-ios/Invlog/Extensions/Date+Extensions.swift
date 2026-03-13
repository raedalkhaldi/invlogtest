import Foundation

extension Date {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// "7 mins ago", "2 hrs ago", "3 days ago" — no seconds
    var shortRelativeString: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins) min\(mins == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hrs = Int(interval / 3600)
            return "\(hrs) hr\(hrs == 1 ? "" : "s") ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }
}

extension Notification.Name {
    static let didCreatePost = Notification.Name("didCreatePost")
    static let didCreateStory = Notification.Name("didCreateStory")
    static let didCreateTrip = Notification.Name("didCreateTrip")
    static let didUpdateTrip = Notification.Name("didUpdateTrip")
    static let didDeleteTrip = Notification.Name("didDeleteTrip")
}
