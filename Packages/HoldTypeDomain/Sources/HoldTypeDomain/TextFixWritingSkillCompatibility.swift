/// Models whose current OpenAI model contracts explicitly support Agent Skills.
public enum TextFixWritingSkillCompatibility {
    private static let supportedAliases: Set<String> = [
        "gpt-5.4",
        "gpt-5.4-mini",
        "gpt-5.4-nano",
        "gpt-5.5",
        "gpt-5.6",
        "gpt-5.6-luna",
        "gpt-5.6-sol",
        "gpt-5.6-terra",
    ]

    public static func supports(model: String) -> Bool {
        if supportedAliases.contains(model) {
            return true
        }

        return supportedAliases.contains { alias in
            model.hasPrefix("\(alias)-20")
        }
    }
}
