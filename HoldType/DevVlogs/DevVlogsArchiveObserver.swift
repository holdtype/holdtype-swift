import Darwin
import Dispatch
import Foundation

@MainActor
protocol DevVlogsArchiveObserving: AnyObject {
    func startObserving(url: URL, onChange: @escaping @MainActor () -> Void)
    func stopObserving()
}

@MainActor
final class DevVlogsArchiveObserver: DevVlogsArchiveObserving {
    private let fileManager: FileManager
    private var observedURL: URL?
    private var onChange: (@MainActor () -> Void)?
    private var sources: [DispatchSourceFileSystemObject] = []

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func startObserving(url: URL, onChange: @escaping @MainActor () -> Void) {
        stopObserving()
        observedURL = url.standardizedFileURL
        self.onChange = onChange
        installSources()
    }

    func stopObserving() {
        observedURL = nil
        onChange = nil
        let sources = sources
        self.sources.removeAll()
        sources.forEach { $0.cancel() }
    }

    private func installSources() {
        let oldSources = sources
        sources.removeAll()
        oldSources.forEach { $0.cancel() }
        guard let observedURL else { return }

        let directories = [observedURL] + descendantDirectories(at: observedURL)
        sources = directories.compactMap { url in
            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor >= 0 else { return nil }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .delete, .rename, .extend, .attrib, .link, .revoke],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.installSources()
                    self.onChange?()
                }
            }
            source.setCancelHandler {
                Darwin.close(descriptor)
            }
            source.resume()
            return source
        }
    }

    private func descendantDirectories(at rootURL: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var directories: [URL] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
                continue
            }
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
            } else if values.isDirectory == true {
                directories.append(url)
            }
        }
        return directories
    }
}
