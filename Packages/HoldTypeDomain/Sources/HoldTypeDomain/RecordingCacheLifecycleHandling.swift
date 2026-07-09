public protocol RecordingCacheLifecycleHandling {
    /// Applies the configured cache lifecycle after every required recovery
    /// ownership handoff for this artifact has succeeded. Implementations may
    /// delete the artifact, so callers must not invoke this while it is the
    /// only recoverable copy of a completed recording.
    func handleCompletedRecording(
        _ artifact: AudioRecordingArtifact,
        policy: RecordingCachePolicy
    ) throws
}
