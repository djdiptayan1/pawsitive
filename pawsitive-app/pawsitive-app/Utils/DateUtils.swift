import Foundation

enum DateUtils {
    static func formatSupabaseDate(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "Recently" }

        let istZone = TimeZone(identifier: "Asia/Kolkata")!
        let parseZone = TimeZone(abbreviation: "UTC")!
        let posixLocale = Locale(identifier: "en_US_POSIX")

        let display = DateFormatter()
        display.dateFormat = "d MMM yyyy, h:mm a"
        display.timeZone = istZone

        let parser = DateFormatter()
        parser.locale = posixLocale
        parser.timeZone = parseZone

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSSSSS",
            "yyyy-MM-dd HH:mm:ss",
        ]
        for fmt in formats {
            parser.dateFormat = fmt
            if let date = parser.date(from: dateStr) {
                return display.string(from: date)
            }
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: dateStr) {
            return display.string(from: date)
        }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: dateStr) {
            return display.string(from: date)
        }
        return "Recently"
    }
}
