import Foundation

enum SettingsViewStateLoader {
    static func loadRecordingCacheState(
        recordingCache: any RecordingCacheManaging
    ) -> (summary: RecordingCacheSummary, errorMessage: String?) {
        do {
            return (try recordingCache.summary(), nil)
        } catch {
            return (
                RecordingCacheSummary(directoryURL: recordingCache.directoryURL, items: []),
                userFacingMessage(for: error)
            )
        }
    }

    static func loadDiagnosticsState(
        diagnostics: any DiagnosticsManaging
    ) -> (summary: DiagnosticReportSummary, errorMessage: String?) {
        do {
            return (try diagnostics.summary(), nil)
        } catch {
            return (
                DiagnosticReportSummary(
                    directoryURL: diagnostics.diagnosticReportsDirectoryURL,
                    directoryStatus: .missing,
                    items: []
                ),
                userFacingMessage(for: error)
            )
        }
    }

    static func loadRuntimeLogState(
        diagnostics: any DiagnosticsManaging
    ) -> (summary: DiagnosticRuntimeLogSummary, errorMessage: String?) {
        do {
            return (try diagnostics.runtimeLogSummary(limit: 100), nil)
        } catch {
            return (
                DiagnosticRuntimeLogSummary(
                    directoryURL: diagnostics.runtimeLogsDirectoryURL,
                    recentLines: []
                ),
                userFacingMessage(for: error)
            )
        }
    }

    static func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }

        return error.localizedDescription
    }
}
