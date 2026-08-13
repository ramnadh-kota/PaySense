/// Configuration for the PaySense AI backend (Cloud Run proxy).
///
/// [baseUrl] is NOT a secret — the OpenAI API key lives only on the backend
/// (see ai_backend/README.md) and is never referenced anywhere in this app.
/// Configure the deployed backend URL at build/run time so it never has to
/// be hardcoded here:
///
///   flutter run --dart-define=AI_BACKEND_BASE_URL=https://your-service.a.run.app
///
/// Left empty by default: with no value configured, [OpenAiService] fails
/// fast with a clear error and the AI chat falls back to local insights
/// rather than silently pointing at a placeholder backend.
class AiBackendConfig {
  const AiBackendConfig._();

  static const String baseUrl = String.fromEnvironment(
    'AI_BACKEND_BASE_URL',
    defaultValue: '',
  );

  static const Duration requestTimeout = Duration(seconds: 20);
}
