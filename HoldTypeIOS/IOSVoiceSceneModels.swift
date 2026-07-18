nonisolated enum IOSVoiceSceneActivity: Equatable, Sendable {
    case active
    case inactive
    case background
}

nonisolated enum IOSVoiceSceneRegistrationMutation: Equatable, Sendable {
    case accepted
    case unchanged
    case stale
}

nonisolated enum IOSVoiceSceneContinuationValidation: Equatable, Sendable {
    case ready
    case awaitingPermissionDecision
    case awaitingInitiatingSceneReactivation
    case stale
}

nonisolated enum IOSVoiceScenePromptPresentation: Equatable, Sendable {
    case available
    case ownedByThisScene
    case ownedByAnotherScene
    case unavailable
}

nonisolated enum IOSVoiceSceneForegroundLossDisposition: Equatable, Sendable {
    case expectedMicrophonePermissionPrompt
    case voiceWorkMustStop
}

nonisolated struct IOSVoiceSceneRegistrySnapshot: Equatable, Sendable {
    let registeredSceneCount: Int
    let foregroundActiveSceneCount: Int
    let isForegroundActive: Bool
}
