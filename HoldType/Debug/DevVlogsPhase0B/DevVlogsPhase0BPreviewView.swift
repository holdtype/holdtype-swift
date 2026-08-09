#if DEBUG
import SwiftUI

struct DevVlogsPhase0BPreviewApplication: App {
    private let configuration: Result<
        DevVlogsPhase0BPreviewConfiguration,
        DevVlogsPhase0BPreviewLaunchError
    >

    init() {
        configuration = DevVlogsPhase0BPreviewConfiguration.resolve(
            environment: ProcessInfo.processInfo.environment
        )
    }

    init(environment: [String: String]) {
        configuration = DevVlogsPhase0BPreviewConfiguration.resolve(environment: environment)
    }

    var body: some Scene {
        WindowGroup("Dev Vlogs Preview") {
            DevVlogsPhase0BPreviewRoot(configuration: configuration)
        }
        .commands {
            CommandGroup(replacing: .newItem) { EmptyView() }
        }
    }
}

private struct DevVlogsPhase0BPreviewRoot: View {
    let configuration: Result<
        DevVlogsPhase0BPreviewConfiguration,
        DevVlogsPhase0BPreviewLaunchError
    >

    var body: some View {
        switch configuration {
        case .success(let configuration):
            DevVlogsPhase0BPreviewContainer(configuration: configuration)
        case .failure(let error):
            ContentUnavailableView(
                "Preview Unavailable",
                systemImage: "video.slash",
                description: Text(error.message)
            )
            .accessibilityIdentifier("devVlogsPhase0B.preview.launchError")
            .frame(minWidth: 560, minHeight: 420)
        }
    }
}

private struct DevVlogsPhase0BPreviewContainer: View {
    @State private var session: DevVlogsPhase0BPreviewSession

    init(configuration: DevVlogsPhase0BPreviewConfiguration) {
        _session = State(initialValue: .live(cameraID: configuration.cameraUniqueID))
    }

    var body: some View {
        DevVlogsPhase0BPreviewView(session: session)
    }
}

struct DevVlogsPhase0BPreviewView: View {
    @Bindable var session: DevVlogsPhase0BPreviewSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Preview Feasibility")
                .font(.title2.weight(.semibold))

            Picker("Camera", selection: $session.selectedCameraID) {
                Text("Choose a camera").tag(String?.none)
                ForEach(session.cameras) { camera in
                    Text(camera.label).tag(Optional(camera.id))
                }
            }
            .accessibilityIdentifier("devVlogsPhase0B.preview.cameraPicker")

            previewSurface

            HStack {
                Label(statusText, systemImage: statusSymbol)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("devVlogsPhase0B.preview.status")

                Spacer()

                Button("Stop") {
                    Task { await session.stop() }
                }
                .disabled(!canStop)
                .accessibilityIdentifier("devVlogsPhase0B.preview.stop")

                Button("Start") {
                    session.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
                .accessibilityIdentifier("devVlogsPhase0B.preview.start")
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
        .onDisappear {
            Task { await session.stop() }
        }
    }

    @ViewBuilder
    private var previewSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)

            if let frame = session.frame {
                Image(decorative: frame, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(x: -1, y: 1)
                    .accessibilityIdentifier("devVlogsPhase0B.preview.image")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "video")
                        .font(.system(size: 36))
                    Text("Preview starts only after Start")
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("devVlogsPhase0B.preview.placeholder")
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .accessibilityLabel("Mirrored live camera preview")
    }

    private var canStart: Bool {
        session.selectedCameraID != nil && ![.starting, .previewing, .stopping].contains(session.state)
    }

    private var canStop: Bool {
        [.starting, .previewing].contains(session.state)
    }

    private var statusText: String {
        switch session.state {
        case .idle: "Idle — camera released"
        case .starting: "Starting preview…"
        case .previewing: "Previewing"
        case .stopping: "Stopping and releasing camera…"
        case .stopped: "Stopped — camera released"
        case .failed(let failure): failure.message
        }
    }

    private var statusSymbol: String {
        switch session.state {
        case .previewing: "video.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .starting, .stopping: "hourglass"
        case .idle, .stopped: "video.slash"
        }
    }

}

private extension DevVlogsPhase0BPreviewFailure {
    var message: String {
        switch self {
        case .selectionRequired: "Choose a camera before starting."
        case .authorizationRequired: "Camera access is not determined; preview will not request it."
        case .authorizationDenied: "Camera access is denied."
        case .authorizationRestricted: "Camera access is restricted."
        case .selectedDeviceMissing: "The selected camera is unavailable."
        case .selectedDeviceBusy: "The selected camera is busy."
        case .disconnected: "The selected camera disconnected."
        case .runtimeFailure: "The preview session failed."
        case .frameConversionFailed: "The preview frame could not be rendered."
        case .startTimedOut: "Preview did not produce a frame within 30 seconds."
        case .cancelled: "Preview start was cancelled."
        }
    }
}

private struct DevVlogsPhase0BPreviewFixturePlatform: DevVlogsPhase0BPreviewPlatform {
    let cameras: [DevVlogsPhase0BPreviewCamera]
    func authorizationStatus() -> DevVlogsPhase0BPreviewAuthorization { .authorized }
    func makeGraph(cameraID: String) throws -> any DevVlogsPhase0BPreviewGraph {
        DevVlogsPhase0BPreviewFixtureGraph()
    }
}

nonisolated private final class DevVlogsPhase0BPreviewFixtureGraph:
    DevVlogsPhase0BPreviewGraph, @unchecked Sendable {
    func start(
        onFrame: @escaping @Sendable (CGImage) -> Void,
        onFailure: @escaping @Sendable (DevVlogsPhase0BPreviewFailure) -> Void
    ) async throws {}
    func stop() async {}
}

@MainActor
private func previewFixture(
    state: DevVlogsPhase0BPreviewState,
    frame: CGImage? = nil
) -> DevVlogsPhase0BPreviewSession {
    let camera = DevVlogsPhase0BPreviewCamera(id: "fixture", label: "Preview Camera")
    return DevVlogsPhase0BPreviewSession(
        platform: DevVlogsPhase0BPreviewFixturePlatform(cameras: [camera]),
        state: state,
        selectedCameraID: "fixture",
        frame: frame
    )
}

#Preview("Idle") {
    DevVlogsPhase0BPreviewView(session: previewFixture(state: .idle))
}

#Preview("Previewing") {
    DevVlogsPhase0BPreviewView(session: previewFixture(state: .previewing))
}

#Preview("Failure") {
    DevVlogsPhase0BPreviewView(
        session: previewFixture(state: .failed(.selectedDeviceBusy))
    )
}
#endif
