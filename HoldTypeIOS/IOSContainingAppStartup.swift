import HoldTypeOpenAI

@MainActor
struct IOSContainingAppStartup {
    init(
        scheduleProviderStartupMaintenance: @MainActor () -> Void = {
            OpenAIProviderStartupMaintenance.schedule()
        },
        scheduleContainingAppRecovery: @MainActor () -> Void
    ) {
        scheduleProviderStartupMaintenance()
        scheduleContainingAppRecovery()
    }
}
