//
//  TranscriptTextCorrectionService.swift
//  HoldType
//
//  Created by Codex on 7/5/26.
//

import Foundation
import HoldTypeDomain

protocol TextCorrectionServing {
    func correct(
        _ transcript: String,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String
    func cancelActiveCorrection()
}

extension TextCorrectionServing {
    func cancelActiveCorrection() {}
}

struct TranscriptTextCorrectionService: TextCorrectionServing {
    private let openAITextCorrectionService: any OpenAITextCorrectionServing
    private let localPostProcessor: TranscriptTextPostProcessor

    init(
        openAITextCorrectionService: any OpenAITextCorrectionServing = OpenAITextCorrectionService(),
        localPostProcessor: TranscriptTextPostProcessor = TranscriptTextPostProcessor()
    ) {
        self.openAITextCorrectionService = openAITextCorrectionService
        self.localPostProcessor = localPostProcessor
    }

    func correct(
        _ transcript: String,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String {
        let normalizedTranscript = AcceptedTranscript.nonEmptyNormalizedText(from: transcript) ?? transcript
        var correctedText = normalizedTranscript

        if settings.textCorrectionEnabled {
            do {
                let openAIText = try await openAITextCorrectionService.correct(
                    normalizedTranscript,
                    settings: settings,
                    credential: credential
                )

                if Self.isSafeCorrection(original: normalizedTranscript, corrected: openAIText) {
                    correctedText = openAIText
                }
            } catch {
                correctedText = normalizedTranscript
            }
        }

        return localPostProcessor.process(correctedText, settings: settings, fallback: normalizedTranscript)
    }

    func cancelActiveCorrection() {
        openAITextCorrectionService.cancelActiveCorrection()
    }

    private static func isSafeCorrection(original: String, corrected: String) -> Bool {
        guard let normalizedCorrection = AcceptedTranscript.nonEmptyNormalizedText(from: corrected) else {
            return false
        }

        let originalCount = original.count
        let correctedCount = normalizedCorrection.count
        guard originalCount >= 20 else {
            return true
        }

        return correctedCount >= max(1, originalCount / 3) && correctedCount <= originalCount * 3
    }
}
