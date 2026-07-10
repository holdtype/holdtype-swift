import Foundation

/// Sealed proof that the containing-app coordinator observed every legacy
/// History owner as absent or empty before creating the physical 1/1 policy.
struct IOSHistoryPolicyBaselineAuthorization: Sendable {
    fileprivate init() {}

    init(testingToken: Void) {}
}

/// Opaque acceptance-time History decision. Public callers can carry this
/// value into delivery preparation but cannot choose a policy generation or
/// construct a pending marker themselves.
public struct IOSAcceptedOutputHistoryCapture: Equatable, Sendable {
    fileprivate let policyReceipt: IOSHistoryPolicyReceipt
    let historyWrite: IOSAcceptedOutputHistoryWrite?

    fileprivate init(
        policyReceipt: IOSHistoryPolicyReceipt,
        historyWrite: IOSAcceptedOutputHistoryWrite?
    ) {
        self.policyReceipt = policyReceipt
        self.historyWrite = historyWrite
    }

    init(
        testingPolicyReceipt policyReceipt: IOSHistoryPolicyReceipt,
        historyWrite: IOSAcceptedOutputHistoryWrite?
    ) {
        self.init(
            policyReceipt: policyReceipt,
            historyWrite: historyWrite
        )
    }
}

extension IOSAcceptedOutputHistoryCapture: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSAcceptedOutputHistoryCapture(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}
