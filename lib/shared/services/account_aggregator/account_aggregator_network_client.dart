import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'account_aggregator_config.dart';
import 'account_aggregator_models.dart';

/// ACCOUNT AGGREGATOR — PRODUCTION HARDENING (Phase A5). A clean HTTP
/// abstraction for talking to PaySense's OWN backend boundary (never
/// directly to an AA/TSP — see PHASE B). Not currently called by any
/// shipping code path (mock/sandbox don't need it) — this exists as the
/// exact seam [ProductionAccountAggregatorProvider] (Phase A2) would use
/// once a real backend exists, built now so that integration is a
/// small, well-tested change rather than a redesign.
///
/// Guarantees:
/// - [config.connectTimeout] is always applied.
/// - Only idempotent GET requests are retried (up to [config.maxRetries])
///   — POST/consent-mutating calls are NEVER auto-retried, since retrying
///   a non-idempotent AA operation could double-initiate a real-world
///   side effect.
/// - Every request carries a fresh correlation id (`X-Request-Id`) for
///   support/debugging — never a credential.
/// - [AccountAggregatorNetworkClient] NEVER logs request/response bodies,
///   headers, or the correlation id's associated payload — only method,
///   path, status code, and duration (see [_safeLog]).
class AccountAggregatorNetworkClient {
  AccountAggregatorNetworkClient({
    required this.config,
    http.Client? httpClient,
    Duration Function(int attempt)? retryDelay,
  })  : _httpClient = httpClient ?? http.Client(),
        _retryDelay = retryDelay ?? _defaultRetryDelay;

  final AccountAggregatorConfig config;
  final http.Client _httpClient;

  /// Delay before retry attempt N (1-indexed) of a retryable request.
  /// Exponential backoff — 250ms, 500ms, 1s, ... capped at 4s — so a
  /// flaky connection doesn't hammer the backend with immediate
  /// back-to-back retries. Injectable so tests never have to sleep.
  final Duration Function(int attempt) _retryDelay;

  static Duration _defaultRetryDelay(int attempt) {
    final ms = 250 * (1 << (attempt - 1));
    return Duration(milliseconds: ms > 4000 ? 4000 : ms);
  }

  /// Logs ONLY method/path/status/duration — see class doc. `path` must
  /// already be free of query-string values that could carry PII; callers
  /// are responsible for that (this client doesn't inspect it further).
  final List<String> debugLog = [];

  Future<Map<String, dynamic>> get(String path) => _send('GET', path, retryable: true);

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body, retryable: false);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool retryable,
  }) async {
    if (!config.isNetworkConfigured) {
      throw const AccountAggregatorException(
        AccountAggregatorErrorCode.configurationMissing,
        'Account Aggregator backend is not configured for this environment.',
      );
    }

    final requestId = const Uuid().v4();
    final uri = Uri.parse('${config.baseUrl}$path');
    final headers = {
      'Content-Type': 'application/json',
      'X-Request-Id': requestId,
      if (config.clientId != null) 'X-Client-Id': config.clientId!,
      // Deliberately NO Authorization header here — a real integration's
      // short-lived session token would be attached by the backend
      // boundary itself (PHASE B), never stored/attached from the
      // Flutter app.
    };

    var attempt = 0;
    final maxAttempts = retryable ? config.maxRetries + 1 : 1;

    while (true) {
      attempt++;
      final stopwatch = Stopwatch()..start();
      try {
        final response = await _httpClient
            .send(
              http.Request(method, uri)
                ..headers.addAll(headers)
                ..body = body != null ? jsonEncode(body) : '',
            )
            .then(http.Response.fromStream)
            .timeout(config.connectTimeout);

        stopwatch.stop();
        _safeLog(method, path, response.statusCode, stopwatch.elapsedMilliseconds);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (response.body.isEmpty) return const {};
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw const AccountAggregatorException(
            AccountAggregatorErrorCode.authenticationFailed,
            'Could not authenticate with the Account Aggregator backend.',
          );
        }
        throw AccountAggregatorException(
          AccountAggregatorErrorCode.providerUnavailable,
          'The Account Aggregator backend returned an unexpected response (${response.statusCode}).',
        );
      } on AccountAggregatorException {
        rethrow;
      } catch (e) {
        stopwatch.stop();
        _safeLog(method, path, null, stopwatch.elapsedMilliseconds);
        final isTimeout = e.toString().contains('TimeoutException');
        if (attempt < maxAttempts) {
          await Future.delayed(_retryDelay(attempt));
          continue;
        }
        throw AccountAggregatorException(
          isTimeout ? AccountAggregatorErrorCode.networkTimeout : AccountAggregatorErrorCode.providerUnavailable,
          isTimeout
              ? 'The connection timed out. Please try again.'
              : 'Your bank connection is temporarily unavailable. Your existing PaySense data is safe.',
        );
      }
    }
  }

  void _safeLog(String method, String path, int? statusCode, int elapsedMs) {
    debugLog.add('$method $path -> ${statusCode ?? "ERROR"} (${elapsedMs}ms)');
  }

  void close() => _httpClient.close();
}
