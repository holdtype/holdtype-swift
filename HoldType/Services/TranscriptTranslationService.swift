//
//  TranscriptTranslationService.swift
//  HoldType
//
//  Created by Codex on 7/5/26.
//

import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

protocol TranscriptTranslationServing {
    func translate(
        _ request: TextTranslationRequest,
        credential: OpenAICredential
    ) async throws -> String
    func cancelActiveTranslation()
}

struct TranscriptTranslationService: TranscriptTranslationServing {
    private let openAITextTranslationService: any OpenAITextTranslationServing

    init(
        openAITextTranslationService: any OpenAITextTranslationServing = OpenAITextTranslationService()
    ) {
        self.openAITextTranslationService = openAITextTranslationService
    }

    func translate(
        _ request: TextTranslationRequest,
        credential: OpenAICredential
    ) async throws -> String {
        let translatedText = try await openAITextTranslationService.translate(
            request,
            credential: credential
        )
        guard let acceptedText = AcceptedTranscript.nonEmptyNormalizedText(from: translatedText) else {
            throw OpenAITextTranslationServiceError.emptyTranslation
        }

        return acceptedText
    }

    func cancelActiveTranslation() {
        openAITextTranslationService.cancelActiveTranslation()
    }
}
