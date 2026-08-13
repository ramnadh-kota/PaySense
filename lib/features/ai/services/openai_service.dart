import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:paysense/core/config/ai_backend_config.dart';
import 'package:paysense/features/ai/services/ai_service.dart';

/// Calls the PaySense AI backend (Cloud Run), which in turn calls OpenAI.
///
/// The OpenAI API key never lives in this app: this service only ever talks
/// to PaySense's own HTTPS backend. See ai_backend/README.md for the backend
/// side of this integration.
class OpenAiService implements AiService {
  OpenAiService({http.Client? client, Duration? timeout, String? baseUrl})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? AiBackendConfig.requestTimeout,
      _baseUrl = baseUrl ?? AiBackendConfig.baseUrl;

  final http.Client _client;
  final Duration _timeout;
  final String _baseUrl;

  static const String _unavailableMessage =
      'AI analysis is temporarily unavailable. Please try again later.';

  @override
  Future<String> ask({
    required String message,
    required String financialContext,
  }) async {
    if (_baseUrl.isEmpty) {
      throw const AiServiceException(
        'AI analysis is not configured yet. Please try again later.',
      );
    }

    final Map<String, dynamic> context;
    try {
      final decoded = jsonDecode(financialContext);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('financialContext is not an object');
      }
      context = decoded;
    } catch (_) {
      throw const AiServiceException(_unavailableMessage);
    }

    final uri = Uri.parse('$_baseUrl/v1/financial-analysis');

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'question': message,
              'financial_context': context,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiServiceException(
        'AI analysis is taking longer than expected. Please try again.',
      );
    } catch (_) {
      throw const AiServiceException(
        'No internet connection. Your local financial insights are still available.',
      );
    }

    if (response.statusCode == 429) {
      throw const AiServiceException(
        'AI is receiving a lot of requests right now. Please try again shortly.',
      );
    }
    if (response.statusCode != 200) {
      throw const AiServiceException(_unavailableMessage);
    }

    final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected response shape');
      }
      body = decoded;
    } catch (_) {
      throw const AiServiceException(
        'AI analysis returned an unexpected response. Please try again later.',
      );
    }

    return _formatResponse(body);
  }

  String _formatResponse(Map<String, dynamic> body) {
    final summary = (body['summary'] as String?)?.trim() ?? '';
    final keyInsights = _stringList(body['key_insights']);
    final positiveTrends = _stringList(body['positive_trends']);
    final areasToImprove = _stringList(body['areas_to_improve']);
    final recommendations = _stringList(body['recommendations']);
    final warnings = _stringList(body['warnings']);

    if (summary.isEmpty &&
        keyInsights.isEmpty &&
        positiveTrends.isEmpty &&
        areasToImprove.isEmpty &&
        recommendations.isEmpty &&
        warnings.isEmpty) {
      throw const AiServiceException(
        'AI analysis returned an unexpected response. Please try again later.',
      );
    }

    final buffer = StringBuffer();
    if (summary.isNotEmpty) {
      buffer.writeln(summary);
    }
    _appendSection(buffer, 'Key Insights', keyInsights);
    _appendSection(buffer, "What You're Doing Well", positiveTrends);
    _appendSection(buffer, 'What To Improve', areasToImprove);
    _appendSection(buffer, 'Recommendations', recommendations);
    _appendSection(buffer, 'Please Note', warnings);

    return buffer.toString().trim();
  }

  void _appendSection(StringBuffer buffer, String title, List<String> items) {
    if (items.isEmpty) return;
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.writeln('$title:');
    for (final item in items) {
      buffer.writeln('• $item');
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }
}
