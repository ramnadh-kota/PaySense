abstract class AiService {
  Future<String> ask({
    required String message,
    required String financialContext,
  });
}

/// A safe-to-display failure from the AI backend/OpenAI pipeline, as
/// distinct from an unexpected exception — [message] is already sanitized
/// and suitable to show directly to the user.
class AiServiceException implements Exception {
  const AiServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
