//
//  RuntimeDiagnosticsLogStore.swift
//  HoldType
//
//  Created by Codex on 7/7/26.
//

import Foundation

enum RuntimeDiagnosticSeverity: String, Equatable {
    case info
    case error
}

struct RuntimeDiagnosticEvent: Equatable {
    let category: String
    let name: String
    let severity: RuntimeDiagnosticSeverity
    let fields: [String: String]

    init(
        category: String,
        name: String,
        severity: RuntimeDiagnosticSeverity = .info,
        fields: [String: String] = [:]
    ) {
        self.category = category
        self.name = name
        self.severity = severity
        self.fields = fields
    }
}

struct RuntimeDiagnosticLogExport: Codable, Equatable {
    let relativePath: String
    let lineCount: Int
}

struct DiagnosticRuntimeLogSummary: Equatable {
    let directoryURL: URL
    let recentLines: [String]

    var lineCount: Int {
        recentLines.count
    }

    var isEmpty: Bool {
        recentLines.isEmpty
    }
}

protocol RuntimeDiagnosticLogRecording {
    func record(_ event: RuntimeDiagnosticEvent)
}

protocol RuntimeDiagnosticLogManaging: RuntimeDiagnosticLogRecording {
    var directoryURL: URL { get }

    func recentLogLines(limit: Int) throws -> [String]
    func exportRecentLogs(to bundleURL: URL, since startDate: Date) throws -> RuntimeDiagnosticLogExport?
    func prune() throws
}

struct RuntimeDiagnosticsLogStore: RuntimeDiagnosticLogManaging {
    static let shared = RuntimeDiagnosticsLogStore()

    private static let logFilePrefix = "runtime-"
    private static let logFileExtension = "log"
    private static let exportedRelativeDirectory = "RuntimeLogs"
    private static let exportedFileName = "runtime-events.log"

    let directoryURL: URL

    private let fileManager: FileManager
    private let now: () -> Date
    private let maximumAge: TimeInterval
    private let maximumTotalByteCount: Int64

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init,
        maximumAge: TimeInterval = 7 * 24 * 60 * 60,
        maximumTotalByteCount: Int64 = 5 * 1024 * 1024
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
        self.now = now
        self.maximumAge = maximumAge
        self.maximumTotalByteCount = maximumTotalByteCount
    }

    func record(_ event: RuntimeDiagnosticEvent) {
        do {
            try append(event)
            try prune()
        } catch {
            // Runtime diagnostics must never interrupt dictation or Settings actions.
        }
    }

    func recentLogLines(limit: Int) throws -> [String] {
        guard limit > 0 else {
            return []
        }

        try prune()
        let lines = try allLogLines()
        return Array(lines.suffix(limit))
    }

    func exportRecentLogs(to bundleURL: URL, since startDate: Date) throws -> RuntimeDiagnosticLogExport? {
        try prune()
        let lines = try allLogLines().filter { line in
            guard let date = Self.date(from: line) else {
                return false
            }

            return date >= startDate
        }

        guard !lines.isEmpty else {
            return nil
        }

        let exportDirectoryURL = bundleURL.appendingPathComponent(Self.exportedRelativeDirectory, isDirectory: true)
        try fileManager.createDirectory(at: exportDirectoryURL, withIntermediateDirectories: true)
        let exportURL = exportDirectoryURL.appendingPathComponent(Self.exportedFileName)
        let contents = lines.joined(separator: "\n") + "\n"
        try contents.write(to: exportURL, atomically: true, encoding: .utf8)

        return RuntimeDiagnosticLogExport(
            relativePath: "\(Self.exportedRelativeDirectory)/\(Self.exportedFileName)",
            lineCount: lines.count
        )
    }

    func prune() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        let cutoffDate = now().addingTimeInterval(-maximumAge)
        for fileURL in try logFileURLs() {
            let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let date = values.contentModificationDate ?? .distantPast
            if date < cutoffDate {
                try fileManager.removeItem(at: fileURL)
            }
        }

        try pruneToMaximumSize()
    }

    private func append(_ event: RuntimeDiagnosticEvent) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let date = now()
        let line = Self.line(for: event, at: date)
        let fileURL = logFileURL(for: date)
        let data = Data((line + "\n").utf8)

        if fileManager.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer {
                try? handle.close()
            }

            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }

    private func allLogLines() throws -> [String] {
        var lines: [String] = []

        for fileURL in try logFileURLs() {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            lines.append(contentsOf:
                contents
                    .split(whereSeparator: \.isNewline)
                    .map(String.init)
            )
        }

        return lines
    }

    private func pruneToMaximumSize() throws {
        guard maximumTotalByteCount > 0 else {
            return
        }

        let files = try logFileURLs()
            .map { fileURL -> (url: URL, size: Int64, date: Date) in
                let values = try fileURL.resourceValues(
                    forKeys: [.fileSizeKey, .contentModificationDateKey]
                )
                return (
                    url: fileURL,
                    size: Int64(values.fileSize ?? 0),
                    date: values.contentModificationDate ?? .distantPast
                )
            }
            .sorted { lhs, rhs in
                lhs.date > rhs.date
            }

        var retainedByteCount: Int64 = 0
        for file in files {
            retainedByteCount += file.size
            if retainedByteCount > maximumTotalByteCount {
                try fileManager.removeItem(at: file.url)
            }
        }
    }

    private func logFileURLs() throws -> [URL] {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }

        return try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter(Self.isRuntimeLogFile)
        .sorted { lhs, rhs in
            lhs.lastPathComponent < rhs.lastPathComponent
        }
    }

    private func logFileURL(for date: Date) -> URL {
        directoryURL.appendingPathComponent(
            "\(Self.logFilePrefix)\(Self.fileDateFormatter.string(from: date)).\(Self.logFileExtension)"
        )
    }

    private static func isRuntimeLogFile(_ fileURL: URL) -> Bool {
        fileURL.lastPathComponent.hasPrefix(logFilePrefix)
            && fileURL.pathExtension == logFileExtension
    }

    private static func line(for event: RuntimeDiagnosticEvent, at date: Date) -> String {
        var parts = [
            isoDateFormatter.string(from: date),
            "category=\(sanitize(event.category))",
            "event=\(sanitize(event.name))",
            "severity=\(event.severity.rawValue)",
        ]

        for key in event.fields.keys.sorted() {
            guard let value = event.fields[key] else {
                continue
            }

            parts.append("\(sanitize(key))=\(sanitize(value))")
        }

        return parts.joined(separator: " ")
    }

    private static func date(from line: String) -> Date? {
        guard let firstToken = line.split(separator: " ").first else {
            return nil
        }

        return isoDateFormatter.date(from: String(firstToken))
    }

    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._:-"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let sanitized = String(scalars)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return sanitized.isEmpty ? "none" : sanitized
    }

    private static var isoDateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    private static var fileDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let cachesRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        return cachesRoot
            .appendingPathComponent("HoldType", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("RuntimeLogs", isDirectory: true)
    }
}
