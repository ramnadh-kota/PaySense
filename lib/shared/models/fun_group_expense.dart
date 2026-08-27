import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'fun_group_expense.g.dart';

/// The special participant id reserved for the signed-in PaySense user
/// within a [FunGroupExpense]. Every other participant is a friend the user
/// typed in by name — PaySense has no contacts/social graph, so a friend is
/// just a label, never a second app account.
const String funGroupExpenseMeParticipantId = 'me';

/// One person's stake in a shared/group expense — either the signed-in user
/// ([funGroupExpenseMeParticipantId]) or a named friend.
@immutable
@HiveType(typeId: 13)
class FunGroupParticipant {
  const FunGroupParticipant({
    required this.id,
    required this.name,
    required this.shareAmount,
    this.isSettled = false,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  /// This participant's portion of the expense's total amount. The sum of
  /// every participant's [shareAmount] always equals the parent
  /// [FunGroupExpense.totalAmount] — enforced by
  /// [FunGroupExpense.equalSplit], never left to drift.
  @HiveField(2)
  final double shareAmount;

  /// Whether this participant's share has been settled: if the user paid
  /// the bill, whether this participant has paid the user back; if someone
  /// else paid, whether the user (or this participant) has settled up with
  /// them. Always true for the participant who actually paid — they can't
  /// owe themselves.
  @HiveField(3)
  final bool isSettled;

  FunGroupParticipant copyWith({
    String? id,
    String? name,
    double? shareAmount,
    bool? isSettled,
  }) {
    return FunGroupParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      shareAmount: shareAmount ?? this.shareAmount,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}

/// A category label for a [FunGroupExpense] — purely descriptive, drives
/// icon choice only. Never used to infer anything financial.
enum FunGroupExpenseCategory {
  dinner,
  movie,
  trip,
  weekend,
  event,
  other,
}

extension FunGroupExpenseCategoryX on FunGroupExpenseCategory {
  static FunGroupExpenseCategory fromKey(String key) {
    return FunGroupExpenseCategory.values.firstWhere(
      (c) => c.name == key,
      orElse: () => FunGroupExpenseCategory.other,
    );
  }

  String get label {
    switch (this) {
      case FunGroupExpenseCategory.dinner:
        return 'Dinner';
      case FunGroupExpenseCategory.movie:
        return 'Movie';
      case FunGroupExpenseCategory.trip:
        return 'Trip';
      case FunGroupExpenseCategory.weekend:
        return 'Weekend';
      case FunGroupExpenseCategory.event:
        return 'Event';
      case FunGroupExpenseCategory.other:
        return 'Shared expense';
    }
  }
}

/// A shared/group expense (dinner, trip, movie, ...) tracked purely for
/// splitting and settlement — never a payment gateway, never sends money.
/// Every field is user-entered; nothing here is inferred or fabricated.
@immutable
@HiveType(typeId: 12)
class FunGroupExpense {
  const FunGroupExpense({
    required this.id,
    required this.title,
    required this.categoryKey,
    required this.totalAmount,
    required this.date,
    required this.paidByParticipantId,
    required this.participants,
    required this.createdAt,
    this.note,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String categoryKey;

  @HiveField(3)
  final double totalAmount;

  @HiveField(4)
  final DateTime date;

  /// The id (see [FunGroupParticipant.id]) of whoever actually fronted the
  /// money — [funGroupExpenseMeParticipantId] or a friend's participant id.
  @HiveField(5)
  final String paidByParticipantId;

  @HiveField(6)
  final List<FunGroupParticipant> participants;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final String? note;

  FunGroupExpenseCategory get category =>
      FunGroupExpenseCategoryX.fromKey(categoryKey);

  bool get iPaid => paidByParticipantId == funGroupExpenseMeParticipantId;

  FunGroupParticipant? get _me {
    for (final p in participants) {
      if (p.id == funGroupExpenseMeParticipantId) {
        return p;
      }
    }
    return null;
  }

  /// The signed-in user's own portion of this expense — 0 if the user
  /// somehow isn't listed as a participant (shouldn't happen; every
  /// expense created in-app always includes "Me").
  double get myShare => _me?.shareAmount ?? 0;

  /// Sum of every other participant's share that hasn't been settled yet.
  /// Only meaningful when [iPaid] is true.
  double get othersOweMe {
    if (!iPaid) return 0;
    return participants
        .where((p) => p.id != funGroupExpenseMeParticipantId && !p.isSettled)
        .fold<double>(0, (sum, p) => sum + p.shareAmount);
  }

  /// What the user still owes the person who paid. Only meaningful when
  /// [iPaid] is false and the user's own share isn't settled yet.
  double get iOwe {
    if (iPaid) return 0;
    final me = _me;
    if (me == null || me.isSettled) return 0;
    return me.shareAmount;
  }

  bool get isFullySettled =>
      participants.where((p) => p.id != paidByParticipantId).every((p) => p.isSettled);

  /// Splits [totalAmount] evenly across every name in [participantNames]
  /// (which must include a "Me" entry) — rounds every share to the nearest
  /// paisa/cent and folds any leftover rounding remainder into the first
  /// participant's share, so shares always sum to exactly [totalAmount].
  static List<FunGroupParticipant> equalSplit({
    required double totalAmount,
    required List<String> participantNames,
  }) {
    if (participantNames.isEmpty) {
      return const [];
    }
    final rawShare = totalAmount / participantNames.length;
    final roundedShare = (rawShare * 100).round() / 100;
    final participants = <FunGroupParticipant>[];
    double allocated = 0;
    for (var i = 0; i < participantNames.length; i++) {
      final isLast = i == participantNames.length - 1;
      final share = isLast
          ? (totalAmount - allocated)
          : roundedShare;
      allocated += share;
      participants.add(
        FunGroupParticipant(
          id: i == 0 ? funGroupExpenseMeParticipantId : 'participant-$i',
          name: participantNames[i],
          shareAmount: double.parse(share.toStringAsFixed(2)),
        ),
      );
    }
    return participants;
  }

  FunGroupExpense copyWith({
    String? title,
    String? categoryKey,
    double? totalAmount,
    DateTime? date,
    String? paidByParticipantId,
    List<FunGroupParticipant>? participants,
    String? note,
  }) {
    return FunGroupExpense(
      id: id,
      title: title ?? this.title,
      categoryKey: categoryKey ?? this.categoryKey,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      paidByParticipantId: paidByParticipantId ?? this.paidByParticipantId,
      participants: participants ?? this.participants,
      createdAt: createdAt,
      note: note ?? this.note,
    );
  }
}
