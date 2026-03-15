import Foundation

/// On-device error logger. Writes errors to a file that can be shared for debugging.
final class ErrorLogger {
    static let shared = ErrorLogger()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.invlog.errorlogger", qos: .utility)
    private let maxFileSize: Int = 500_000 // ~500KB, auto-trims older entries

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("invlog_error_log.txt")
    }

    // MARK: - Public API

    /// Log an error with context about where it happened.
    func log(_ error: Error, context: String, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let entry = formatEntry(
            level: "ERROR",
            context: context,
            message: error.localizedDescription,
            detail: String(describing: error),
            source: "\(fileName):\(line)"
        )
        append(entry)
    }

    /// Log an API error with request details.
    func logAPI(endpoint: String, statusCode: Int?, error: Error) {
        let entry = formatEntry(
            level: "API",
            context: endpoint,
            message: "HTTP \(statusCode ?? 0) — \(error.localizedDescription)",
            detail: String(describing: error),
            source: nil
        )
        append(entry)
    }

    /// Log a warning (non-fatal issue).
    func warn(_ message: String, context: String, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let entry = formatEntry(
            level: "WARN",
            context: context,
            message: message,
            detail: nil,
            source: "\(fileName):\(line)"
        )
        append(entry)
    }

    /// Log app lifecycle events (launch, background, crash recovery).
    func logEvent(_ message: String) {
        let entry = formatEntry(
            level: "EVENT",
            context: "App",
            message: message,
            detail: nil,
            source: nil
        )
        append(entry)
    }

    /// Get the full log contents as a string.
    func getLog() -> String {
        queue.sync {
            (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "(empty log)"
        }
    }

    /// Get the log file URL for sharing.
    func getLogFileURL() -> URL {
        fileURL
    }

    /// Clear the log file.
    func clearLog() {
        queue.async { [fileURL] in
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Private

    private func formatEntry(level: String, context: String, message: String, detail: String?, source: String?) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var line = "[\(timestamp)] [\(level)] [\(context)]"
        if let source { line += " (\(source))" }
        line += " \(message)"
        if let detail, detail != message {
            // Trim long details
            let trimmed = detail.count > 500 ? String(detail.prefix(500)) + "..." : detail
            line += "\n  Detail: \(trimmed)"
        }
        return line
    }

    private func append(_ entry: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let line = entry + "\n"

            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    if let data = line.data(using: .utf8) {
                        handle.write(data)
                    }
                    handle.closeFile()
                }
            } else {
                try? line.write(to: fileURL, atomically: true, encoding: .utf8)
            }

            // Auto-trim if file is too large
            trimIfNeeded()
        }
    }

    private func trimIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int,
              size > maxFileSize else { return }

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n")
        // Keep the last 60% of lines
        let keepFrom = lines.count * 4 / 10
        let trimmed = lines[keepFrom...].joined(separator: "\n")
        try? trimmed.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
