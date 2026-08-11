import Foundation

enum DevVlogsApplicationResolutionError: Error, Equatable {
    case notAnApplicationBundle
    case missingBundleIdentifier

    var message: String {
        switch self {
        case .notAnApplicationBundle:
            return "Choose a macOS application bundle."
        case .missingBundleIdentifier:
            return "This application does not provide a bundle identifier, so it cannot be used for Dev Vlogs."
        }
    }
}

protocol DevVlogsApplicationResolving {
    func resolveApplication(at url: URL) -> Result<DevVlogsApplication, DevVlogsApplicationResolutionError>
}

struct BundleDevVlogsApplicationResolver: DevVlogsApplicationResolving {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func resolveApplication(at url: URL) -> Result<DevVlogsApplication, DevVlogsApplicationResolutionError> {
        guard url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url),
              bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
              isUsableExecutable(in: bundle) else {
            return .failure(.notAnApplicationBundle)
        }

        guard let bundleIdentifier = bundle.bundleIdentifier,
              let application = DevVlogsApplication(
                  bundleIdentifier: bundleIdentifier,
                  displayName: displayName(for: bundle, fallbackURL: url)
              ) else {
            return .failure(.missingBundleIdentifier)
        }

        return .success(application)
    }

    private func displayName(for bundle: Bundle, fallbackURL: URL) -> String {
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        return displayName ?? bundleName ?? fallbackURL.deletingPathExtension().lastPathComponent
    }

    private func isUsableExecutable(in bundle: Bundle) -> Bool {
        guard let executableURL = bundle.executableURL,
              let attributes = try? fileManager.attributesOfItem(atPath: executableURL.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              fileManager.isExecutableFile(atPath: executableURL.path) else {
            return false
        }

        return true
    }
}
