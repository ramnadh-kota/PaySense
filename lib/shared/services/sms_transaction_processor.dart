import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/notification_provider.dart';
import 'package:paysense/shared/providers/sms_review_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/sms_fingerprint_repository.dart';
import 'package:paysense/shared/services/sms_channel.dart';
import 'package:paysense/shared/utils/sms_transaction_parser.dart';
import 'package:paysense/shared/utils/sms_wallet_matcher.dart';

/// How confident [SmsTransactionParser] was that a message is a genuine,
/// correctly-classified transaction, bucketed into the three tiers this
/// feature is specified around. HIGH auto-creates a transaction; MEDIUM
/// goes to manual review; LOW is ignored outright. In practice the parser
/// currently never returns a confidence below MEDIUM's floor for a
/// non-null result (it returns null instead), but the tier still exists so
/// the processor has a well-defined, testable boundary independent of the
/// parser's current tuning.
enum SmsConfidenceTier { high, medium, low }

SmsConfidenceTier tierForConfidence(double confidence) {
  if (confidence >= ParsedSmsTransaction.autoAddConfidenceThreshold) {
    return SmsConfidenceTier.high;
  }
  if (confidence >= 0.3) {
    return SmsConfidenceTier.medium;
  }
  return SmsConfidenceTier.low;
}

/// Purely informational tally of what one [SmsTransactionProcessor.processEvents]
/// call did — useful for tests and for a future "N transactions added from
/// SMS" summary; nothing else in the app currently reads it.
class SmsProcessingSummary {
  const SmsProcessingSummary({
    this.autoAdded = 0,
    this.sentToReview = 0,
    this.ignored = 0,
    this.duplicatesSkipped = 0,
    this.transfersCreated = 0,
  });

  final int autoAdded;
  final int sentToReview;
  final int ignored;
  final int duplicatesSkipped;
  final int transfersCreated;

  SmsProcessingSummary _plus({
    int autoAdded = 0,
    int sentToReview = 0,
    int ignored = 0,
    int duplicatesSkipped = 0,
    int transfersCreated = 0,
  }) {
    return SmsProcessingSummary(
      autoAdded: this.autoAdded + autoAdded,
      sentToReview: this.sentToReview + sentToReview,
      ignored: this.ignored + ignored,
      duplicatesSkipped: this.duplicatesSkipped + duplicatesSkipped,
      transfersCreated: this.transfersCreated + transfersCreated,
    );
  }
}

/// Centralized orchestration turning a batch of incoming bank/UPI SMS into
/// real transactions. This is the ONE place that logic lives — the native
/// Android receiver only captures and persists raw events (sender/body/
/// timestamp), and every Riverpod provider it touches (wallets,
/// transactions, notifications, SMS review) is called from here rather
/// than having its own slice of SMS-specific logic.
///
/// Pipeline per event: parse → duplicate check → (transfer branch) →
/// confidence tier → wallet match → automatic transaction OR review item →
/// wallet balance mutation → notification → mark fingerprint processed.
class SmsTransactionProcessor {
  SmsTransactionProcessor(
    this._ref, {
    SmsChannel? channel,
    SmsFingerprintRepository? fingerprintRepository,
  }) : _channel = channel ?? SmsChannel(),
       _fingerprintRepository = fingerprintRepository ?? SmsFingerprintRepository.instance;

  final Ref _ref;
  final SmsChannel _channel;
  final SmsFingerprintRepository _fingerprintRepository;

  /// Fetches whatever the native receiver has queued and processes it —
  /// the entry point used at app startup / from the review screen's
  /// pull-to-refresh. Acknowledges every fetched event with the native
  /// side afterward regardless of outcome, so a permanently-unparseable
  /// SMS is never retried forever.
  Future<SmsProcessingSummary> processPending() async {
    final events = await _channel.fetchPending();
    if (events.isEmpty) {
      return const SmsProcessingSummary();
    }
    final summary = await processEvents(events);
    await _channel.acknowledge(events.map((event) => event.nativeId).toList());
    return summary;
  }

  /// Processes an explicit batch of already-fetched events. This is the
  /// method tests exercise directly, so none of them need a real platform
  /// channel to verify processor behavior.
  Future<SmsProcessingSummary> processEvents(List<RawSmsEvent> events) async {
    var summary = const SmsProcessingSummary();
    for (final event in events) {
      summary = await _processOne(event, summary);
    }
    return summary;
  }

  Future<SmsProcessingSummary> _processOne(
    RawSmsEvent event,
    SmsProcessingSummary summary,
  ) async {
    final parsed = SmsTransactionParser.parse(
      sender: event.sender,
      body: event.body,
      timestamp: event.timestamp,
    );
    if (parsed == null) {
      // Non-financial / unparseable — nothing to remember, nothing to act
      // on. (Raw event.body is never retained beyond this point either
      // way: it lives only in `event`, a local variable that goes out of
      // scope once this loop iteration ends.)
      return summary;
    }

    if (_fingerprintRepository.isProcessed(parsed.fingerprint)) {
      return summary._plus(duplicatesSkipped: 1);
    }

    final wallets = await _ref.read(walletsProvider.future);

    if (parsed.isLikelyTransfer) {
      return _handleTransfer(parsed, wallets, summary);
    }

    final tier = tierForConfidence(parsed.confidence);
    if (tier == SmsConfidenceTier.low) {
      await _fingerprintRepository.markProcessed(parsed.fingerprint);
      return summary._plus(ignored: 1);
    }

    final match = matchWalletForSms(
      sender: parsed.sender,
      merchant: parsed.merchant,
      wallets: wallets,
    );

    if (tier == SmsConfidenceTier.high && match.isConfident) {
      await _autoCreateTransaction(parsed, match.walletId!, wallets);
      await _fingerprintRepository.markProcessed(parsed.fingerprint);
      return summary._plus(autoAdded: 1);
    }

    // Either MEDIUM confidence, or HIGH confidence but the wallet is
    // unmatched/ambiguous — either way, never guess; surface for review.
    await _createReviewItem(parsed, match.walletId, isLikelyTransfer: false);
    await _fingerprintRepository.markProcessed(parsed.fingerprint);
    return summary._plus(sentToReview: 1);
  }

  Future<SmsProcessingSummary> _handleTransfer(
    ParsedSmsTransaction parsed,
    List<Wallet> wallets,
    SmsProcessingSummary summary,
  ) async {
    final transferMatch = matchTransferWallets(
      sender: parsed.sender,
      merchant: parsed.merchant,
      wallets: wallets,
    );

    if (!transferMatch.isConfident) {
      await _createReviewItem(parsed, transferMatch.sourceWalletId, isLikelyTransfer: true);
      await _fingerprintRepository.markProcessed(parsed.fingerprint);
      return summary._plus(sentToReview: 1);
    }

    try {
      await _ref
          .read(walletsProvider.notifier)
          .transfer(
            fromWalletId: transferMatch.sourceWalletId!,
            toWalletId: transferMatch.destinationWalletId!,
            amount: parsed.amount,
            note: 'Detected from SMS',
          );
    } on WalletTransferException {
      // e.g. insufficient balance — a mis-parsed amount is more likely
      // than a real overdraft, so this goes to review instead of being
      // silently dropped.
      await _createReviewItem(parsed, transferMatch.sourceWalletId, isLikelyTransfer: true);
      await _fingerprintRepository.markProcessed(parsed.fingerprint);
      return summary._plus(sentToReview: 1);
    }

    await _fingerprintRepository.markProcessed(parsed.fingerprint);
    return summary._plus(transfersCreated: 1);
  }

  Future<void> _autoCreateTransaction(
    ParsedSmsTransaction parsed,
    String walletId,
    List<Wallet> wallets,
  ) async {
    final transactionRepository = _ref.read(transactionRepositoryProvider);
    final walletRepository = _ref.read(walletRepositoryProvider);

    final isExpense = parsed.direction == SmsTransactionDirection.debit;
    final title = parsed.merchant ?? (isExpense ? 'Card/UPI payment' : 'Bank credit');

    await transactionRepository.add(
      Transaction(
        id: const Uuid().v4(),
        title: title,
        amount: parsed.amount,
        categoryId: isExpense ? 'Uncategorized' : 'Income',
        // Always a real Wallet.id — same single source of truth as every
        // other transaction-creating path in the app.
        accountId: walletId,
        transactionType: isExpense ? 'expense' : 'income',
        paymentMethod: 'sms',
        note: '',
        createdAt: parsed.timestamp,
      ),
    );

    if (isExpense) {
      await walletRepository.decreaseBalance(walletId, parsed.amount);
    } else {
      await walletRepository.increaseBalance(walletId, parsed.amount);
    }

    _ref.invalidate(transactionsProvider);
    _ref.invalidate(walletsProvider);

    final matchingWallets = wallets.where((w) => w.id == walletId);
    final walletName = matchingWallets.isEmpty ? null : matchingWallets.first.name;

    await _ref.read(notificationsProvider.notifier).addIfNotExists(
      AppNotification(
        id: 'sms-auto:${parsed.fingerprint}',
        title: 'Transaction added',
        message: isExpense
            ? '₹${parsed.amount.toStringAsFixed(0)} spent'
                '${parsed.merchant != null ? ' at ${parsed.merchant}' : ''}'
                '${walletName != null ? ' — $walletName' : ''}'
            : '₹${parsed.amount.toStringAsFixed(0)} received'
                '${walletName != null ? ' — $walletName' : ''}',
        type: NotificationType.smsTransaction.name,
        createdAt: DateTime.now(),
        relatedRoute: AppRoutes.transactions,
      ),
    );
  }

  Future<void> _createReviewItem(
    ParsedSmsTransaction parsed,
    String? suggestedWalletId, {
    required bool isLikelyTransfer,
  }) async {
    final repository = _ref.read(smsReviewRepositoryProvider);
    final inserted = await repository.addIfNotExists(
      SmsReviewItem.create(
        id: parsed.fingerprint,
        amount: parsed.amount,
        direction: parsed.direction == SmsTransactionDirection.debit
            ? SmsReviewDirection.debit
            : SmsReviewDirection.credit,
        sender: parsed.sender,
        timestamp: parsed.timestamp,
        confidence: parsed.confidence,
        isLikelyTransfer: isLikelyTransfer,
        merchant: parsed.merchant,
        suggestedWalletId: suggestedWalletId,
      ),
    );
    if (!inserted) {
      return;
    }

    _ref.invalidate(smsReviewItemsProvider);

    await _ref.read(notificationsProvider.notifier).addIfNotExists(
      AppNotification(
        id: 'sms-review:${parsed.fingerprint}',
        title: 'Transaction detected',
        message:
            '₹${parsed.amount.toStringAsFixed(0)}'
            '${parsed.merchant != null ? ' at ${parsed.merchant}' : ''} — tap to review',
        type: NotificationType.smsTransaction.name,
        createdAt: DateTime.now(),
        relatedRoute: AppRoutes.smsReview,
      ),
    );
  }
}
