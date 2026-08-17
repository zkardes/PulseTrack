import Foundation

enum Fmt {
    static func duration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func hoursMinutes(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    static func int(_ v: Double?) -> String {
        guard let v else { return "--" }
        return String(Int(v.rounded()))
    }

    static func km(_ meters: Double?) -> String {
        guard let meters else { return "--" }
        return String(format: "%.2f", meters / 1000)
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "--" }
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: date)
    }
}
