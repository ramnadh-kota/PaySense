import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/features/ai/models/chat_message.dart';
import 'dart:convert';

import 'package:paysense/features/ai/services/ai_service.dart';
import 'package:paysense/features/ai/services/gemini_ai_service.dart';
import 'package:paysense/features/ai/services/financial_context_builder.dart';

/// Provider for the AI service implementation.
///
/// No concrete implementation is registered by default; consumers should
/// override this provider in tests or higher-level composition to provide
/// a real `AiService` implementation.
final aiServiceProvider = Provider<AiService>((ref) {
  return const GeminiAiService();
});

final aiChatProvider = AsyncNotifierProvider<AiChatNotifier, List<ChatMessage>>(
  AiChatNotifier.new,
);

class AiChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  @override
  Future<List<ChatMessage>> build() async {
    return <ChatMessage>[];
  }

  Future<void> sendMessage(String message) async {
    final now = DateTime.now();
    final userMessage = ChatMessage(
      id: now.microsecondsSinceEpoch.toString(),
      text: message,
      isUser: true,
      createdAt: now,
    );

    // Append user's message first to preserve chronological order.
    final current = state.asData?.value ?? <ChatMessage>[];
    state = AsyncValue.data([...current, userMessage]);

    try {
      // Build financial context and call the AI service.
      final financialContext = await FinancialContextBuilder.instance.build();
      final service = ref.read(aiServiceProvider);

      final fcString = jsonEncode(financialContext.toMap());
      final aiResponse = await service.ask(
        message: message,
        financialContext: fcString,
      );

      final responseMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: aiResponse,
        isUser: false,
        createdAt: DateTime.now(),
      );

      final updated = [
        ...(state.asData?.value ?? <ChatMessage>[]),
        responseMsg,
      ];
      state = AsyncValue.data(updated);
    } catch (e) {
      // On error, preserve existing messages and append an error response.
      final errorMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: 'Error: could not get AI response',
        isUser: false,
        createdAt: DateTime.now(),
      );
      final updated = [...(state.asData?.value ?? <ChatMessage>[]), errorMsg];
      state = AsyncValue.data(updated);
    }
  }
}
