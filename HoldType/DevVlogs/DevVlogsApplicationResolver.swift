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
    func resolveApplication(at url: URL) -> Result<DevVlogsApplication, DevVlogsApplicationResolutionError> {
        guard url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url),
              bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL" else {
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
}
