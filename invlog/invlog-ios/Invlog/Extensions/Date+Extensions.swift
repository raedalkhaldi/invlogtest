import Foundation

extension Date {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension Notification.Name {
    static let didCreatePost = Notification.Name("didCreatePost")
    static let didCreateStory = Notification.Name("didCreateStory")
    static let didCreateTrip = Notification.Name("didCreateTrip")
    static let didUpdateTrip = Notification.Name("didUpdateTrip")
    static let didDeleteTrip = Notification.Name("didDeleteTrip")
}
