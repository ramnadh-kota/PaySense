import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paysense/features/ai/services/ai_service.dart';
import 'package:paysense/features/ai/services/openai_service.dart';

const _baseUrl = 'https://ai-backend.example.test';
const _fcJson = '{"fullName":"Test User","monthlyIncome":50000}';

void main() {
  group('OpenAiService request construction', () {
    test('posts question and financial_context to the configured backend', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;

      final service = OpenAiService(
        baseUrl: _baseUrl,
        client: MockClient((request) async {
          capturedUri = request.url;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'summary': 'You are on track this month.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await service.ask(message: 'How am I doing?', financialContext: _fcJson);

      expect(capturedUri, Uri.parse('$_baseUrl/v1/financial-analysis'));
      expect(capturedBody!['question'], 'How am I doing?');
      expect(capturedBody!['financial_context'], jsonDecode(_fcJson));
    });

    test('never includes the OpenAI API key concept anywhere client-side', () async {
      // OpenAiService has no notion of an API key at all — this documents
      // that expectation so a future change adding one would fail loudly.
      final service = OpenAiService(
        baseUrl: _baseUrl,
        client: MockClient((request) async {
          expect(request.headers.containsKey('x-api-key'), isFalse);
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(jsonEncode({'summary': 'ok'}), 200);
        }),
      );
      await service.ask(message: 'hi', financialContext: _fcJson);
    });
  });

  group('OpenAiService response parsing', () {
    test('formats a well-formed structured response into readable text', () async {
      final service = OpenAiService(
        baseUrl: _baseUrl,
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'summary': 'You spent within budget this month.',
              'key_insights': ['Expenses are 60% of income'],
              'positive_trends': ['Savings rate improved'],
              'areas_to_improve': [],
              'recommendations': ['Increase your emergency fund'],
              'warnings': [],
            }),
            200,
          );
        }),
      );

      final result = await service.ask(message: 'summary', financialContext: _fcJson);

      expect(result, contains('You spent within budget this month.'));
      expect(result, contains('Key Insights:'));
      expect(result, contains('Expenses are 60% of income'));
      expect(result, contains("What You're Doing Well:"));
      expect(result, contains('Recommendations:'));
      expect(result, isNot(contains('What To Improve:')));
      expect(result, isNot(contains('Please Note:')));
    });

    test('throws AiServiceException when response body is not JSON', () async {
      final service = OpenAiService(
        baseUrl: _baseUrl,
        client: MockClient((request) async {
          return http.Response('not json', 200);
        }),
      );

      expect(
        () => service.ask(message: 'hi', financialContext: _fcJson),
        throwsA(isA<AiServiceException>()),
      );
    });

    test('throws AiServiceException when structured fields are all empty', () async {
      final service = OpenAiService(
        baseUrl: _baseUrl,
        client: MockClient((request) async {
          return http.Response(jsonEncode(<String, dynamic>{}), 200);
        }),
      );

      expect(
        () => service.ask(message: 'hi', financialContext: _fcJson),
        throwsA(isA<AiServiceException>()),
      );
    });
  });

  group('OpenAiService error handling', () {
    test('maps HTTP 429 to a rate-limit AiServiceException', () async {
      final service = OpenAiService(
        baseUrl: _baseUrl,
        client: MockClient((request) async => http.Response('', 429)),
      );

      await expectLater(
        service.ask(message: 'hi', financialContext: _fcJson),
        throwsA(
          isA<AiServiceException>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains('requests'),
          ),
        ),
      );
    });

    test('maps a non-200/429 status to a generic unavailable message', () async {
      final service = OpenAiService(
        baseUrl: _baseUrl,
        client: MockClient((request) async => http.Response('', 500)),
      );

      expect(
        () => service.ask(message: 'hi', financialContext: _fcJson),
        throwsA(isA<AiServiceException>()),
      );
    });

    test('maps a client-thrown network failure to a no-internet message', () async {
      final service = OpenAiService(
        baseUrl: _baseUrl,
        client: MockClient((request) async => throw Exception('socket closed')),
      );

      await expectLater(
        service.ask(message: 'hi', financialContext: _fcJson),
        throwsA(
          isA<AiServiceException>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains('internet'),
          ),
        ),
      );
    });

    test('maps a timeout to a timeout AiServiceException', () async {
      final service = OpenAiService(
        baseUrl: _baseUrl,
        timeout: const Duration(milliseconds: 20),
        client: MockClient((request) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          return http.Response(jsonEncode({'summary': 'too slow'}), 200);
        }),
      );

      await expectLater(
        service.ask(message: 'hi', financialContext: _fcJson),
        throwsA(
          isA<AiServiceException>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains('longer than expected'),
          ),
        ),
      );
    });

    test('fails fast with a clear message when no backend URL is configured', () async {
      final service = OpenAiService(baseUrl: '', client: MockClient((request) async {
        fail('should not make a network call when baseUrl is empty');
      }));

      expect(
        () => service.ask(message: 'hi', financialContext: _fcJson),
        throwsA(isA<AiServiceException>()),
      );
    });
  });
}
