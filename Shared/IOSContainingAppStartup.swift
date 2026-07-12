import HoldTypeOpenAI

@MainActor
struct IOSContainingAppStartup {
    init(
        scheduleProviderStartupMaintenance: @MainActor () -> Void = {
            OpenAIProviderStartupMaintenance.schedule()
        },
        scheduleRetryScratchStartupMaintenance: @MainActor () -> Void,
        scheduleContainingAppRecovery: @MainActor () -> Void
    ) {
        scheduleProviderStartupMaintenance()
        scheduleRetryScratchStartupMaintenance()
        scheduleContainingAppRecovery()
    }
}
