import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/ai/models/chat_message.dart';
import 'package:paysense/features/ai/providers/ai_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(aiChatProvider.notifier).sendMessage(text);
    _controller.clear();
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bgColor = isUser ? AppColors.primary : AppColors.surface;
    final textColor = isUser ? Colors.white : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ),
        Text(
          _shortDate(message.createdAt),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  String _shortDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final userName = userProfileAsync.asData?.value?.fullName ?? 'User';

    final chatState = ref.watch(aiChatProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Hello, $userName',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "I'm your PaySense AI Coach.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Quick suggestions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                      'Can I afford a bike?',
                      'How much did I spend this month?',
                      'Help me save more.',
                      'Review my spending.',
                    ].map((s) {
                      return ActionChip(
                        label: Text(s),
                        onPressed: () =>
                            ref.read(aiChatProvider.notifier).sendMessage(s),
                        backgroundColor: AppColors.surface,
                        labelStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textPrimary),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 16),

              // Conversation area
              Expanded(
                child: AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: chatState.when(
                      data: (messages) {
                        final list = messages;
                        if (list.isEmpty) {
                          return Center(
                            child: Text(
                              'Ask me anything about your money.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          );
                        }

                        return ListView.separated(
                          reverse: false,
                          itemCount: list.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final message = list[index];
                            return Align(
                              alignment: message.isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: _buildMessageBubble(message),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text(
                          'Unable to load conversation',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
