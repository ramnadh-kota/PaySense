import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/features/ai/models/chat_message.dart';
import 'dart:convert';

import 'package:paysense/features/ai/models/financial_context.dart';
import 'package:paysense/features/ai/services/ai_service.dart';
import 'package:paysense/features/ai/services/openai_service.dart';
import 'package:paysense/features/ai/services/financial_context_builder.dart';

/// Provider for the AI service implementation. Talks to the PaySense AI
/// backend (Cloud Run) over HTTPS — see ai_backend/README.md. The OpenAI API
/// key is never present in this app.
final aiServiceProvider = Provider<AiService>((ref) {
  return OpenAiService();
});

final aiChatProvider = AsyncNotifierProvider<AiChatNotifier, List<ChatMessage>>(
  AiChatNotifier.new,
);

class AiChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  /// Guards against firing a second AI request while one is already in
  /// flight (e.g. a rapid double-tap on send, or a suggestion chip tapped
  /// mid-request) — keeps backend/OpenAI usage bounded to one call per user
  /// action, mirroring the in-flight guard pattern used by BillsNotifier and
  /// LoansNotifier for their own duplicate-trigger risks.
  bool _isSending = false;

  @override
  Future<List<ChatMessage>> build() async {
    return <ChatMessage>[];
  }

  Future<void> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _isSending) return;

    _isSending = true;
    try {
      final now = DateTime.now();
      final userMessage = ChatMessage(
        id: now.microsecondsSinceEpoch.toString(),
        text: trimmed,
        isUser: true,
        createdAt: now,
      );

      final withUserMessage = [
        ...(state.asData?.value ?? const <ChatMessage>[]),
        userMessage,
      ];
      // Keep existing messages visible (via copyWithPrevious) while the
      // request is in flight rather than blanking the conversation.
      state = AsyncData(withUserMessage);
      state = const AsyncLoading<List<ChatMessage>>().copyWithPrevious(state);

      FinancialContext financialContext;
      try {
        financialContext = await FinancialContextBuilder.instance.build();
      } catch (_) {
        state = AsyncData([
          ...withUserMessage,
          _reply(
            'Unable to load your financial data right now. Please try again later.',
          ),
        ]);
        return;
      }

      String replyText;
      try {
        final service = ref.read(aiServiceProvider);
        final fcString = jsonEncode(financialContext.toMap());
        final aiResponse = await service.ask(
          message: trimmed,
          financialContext: fcString,
        );
        replyText = aiResponse;
      } on AiServiceException catch (e) {
        replyText = _fallbackText(e.message, financialContext);
      } catch (_) {
        replyText = _fallbackText(
          'AI analysis is temporarily unavailable. Please try again later.',
          financialContext,
        );
      }

      state = AsyncData([...withUserMessage, _reply(replyText)]);
    } finally {
      _isSending = false;
    }
  }

  ChatMessage _reply(String text) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      createdAt: DateTime.now(),
    );
  }

  /// When OpenAI/the backend is unavailable, degrade gracefully using the
  /// financial data PaySense already computed locally rather than a bare
  /// error — the app must remain useful without OpenAI.
  String _fallbackText(String reason, FinancialContext context) {
    final buffer = StringBuffer(reason);
    if (context.financialHealthStatus.isNotEmpty) {
      buffer.writeln();
      buffer.writeln();
      buffer.write(
        "Here's what your local Financial Health shows: "
        '${context.financialHealthScore}/100 (${context.financialHealthStatus}).',
      );
      if (context.topFinancialInsight.isNotEmpty) {
        buffer.writeln();
        buffer.write(context.topFinancialInsight);
      }
    }
    return buffer.toString().trim();
  }
}
