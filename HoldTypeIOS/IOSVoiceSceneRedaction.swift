extension IOSVoiceSceneIdentity:
    CustomDebugStringConvertible,
    CustomReflectable,
    CustomStringConvertible {
    var description: String { "IOSVoiceSceneIdentity" }
    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["identity": "opaque"])
    }
}

extension IOSVoiceScenePromptDecisionCapability:
    CustomDebugStringConvertible,
    CustomReflectable,
    CustomStringConvertible {
    var description: String { "IOSVoiceScenePromptDecisionCapability" }
    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["capability": "opaque"])
    }
}

extension IOSVoiceSceneStartLease:
    CustomDebugStringConvertible,
    CustomReflectable,
    CustomStringConvertible {
    var description: String { "IOSVoiceSceneStartLease" }
    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["lease": "opaque"])
    }
}

extension IOSVoiceSceneRegistryEvent:
    CustomDebugStringConvertible,
    CustomReflectable,
    CustomStringConvertible {
    var description: String { "IOSVoiceSceneRegistryEvent" }
    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["event": "content-free"])
    }
}
