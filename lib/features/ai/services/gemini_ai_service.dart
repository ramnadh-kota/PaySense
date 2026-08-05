import 'package:paysense/features/ai/services/ai_service.dart';

/// A mocked concrete implementation of [AiService].
///
/// This does not call any external API; it returns a canned response so the
/// rest of the application can be developed and tested without network
/// integration.
class GeminiAiService implements AiService {
  const GeminiAiService();

  @override
  Future<String> ask({
    required String message,
    required String financialContext,
  }) async {
    return '''Thanks for your question.

Based on your financial profile, I'll be able to answer once Gemini API integration is configured.''';
  }
}
