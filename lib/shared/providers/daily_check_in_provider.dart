import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/app_settings_repository.dart';

class DailyCheckInState {
  const DailyCheckInState({
    required this.lastCheckInDate,
    required this.mood,
    required this.streakDays,
    required this.isCheckedInToday,
  });

  final DateTime? lastCheckInDate;
  final String? mood; // 'comfortable', 'unsure', 'concerned'
  final int streakDays;
  final bool isCheckedInToday;

  DailyCheckInState copyWith({
    DateTime? lastCheckInDate,
    String? mood,
    int? streakDays,
    bool? isCheckedInToday,
  }) {
    return DailyCheckInState(
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
      mood: mood ?? this.mood,
      streakDays: streakDays ?? this.streakDays,
      isCheckedInToday: isCheckedInToday ?? this.isCheckedInToday,
    );
  }
}

class DailyCheckInNotifier extends StateNotifier<DailyCheckInState> {
  DailyCheckInNotifier()
      : super(
          const DailyCheckInState(
            lastCheckInDate: null,
            mood: null,
            streakDays: 1,
            isCheckedInToday: false,
          ),
        ) {
    _load();
  }

  void _load() {
    final repo = AppSettingsRepository.instance;
    final lastIso = repo.dailyCheckInLastDateIso();
    final mood = repo.dailyCheckInMood();
    final streak = repo.dailyAwarenessStreak();
    final lastStreakIso = repo.dailyStreakLastDateIso();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? lastDate;
    if (lastIso != null && lastIso.isNotEmpty) {
      lastDate = DateTime.tryParse(lastIso);
    }

    final isToday = lastDate != null &&
        lastDate.year == today.year &&
        lastDate.month == today.month &&
        lastDate.day == today.day;

    int currentStreak = streak <= 0 ? 1 : streak;
    if (lastStreakIso != null && lastStreakIso.isNotEmpty) {
      final lastStreakDate = DateTime.tryParse(lastStreakIso);
      if (lastStreakDate != null) {
        final diffDays = today.difference(DateTime(lastStreakDate.year, lastStreakDate.month, lastStreakDate.day)).inDays;
        if (diffDays > 2) {
          currentStreak = (currentStreak - (diffDays - 1)).clamp(1, 999);
        }
      }
    }

    state = DailyCheckInState(
      lastCheckInDate: lastDate,
      mood: isToday ? mood : null,
      streakDays: currentStreak,
      isCheckedInToday: isToday,
    );
  }

  Future<void> submitCheckIn(String mood) async {
    final repo = AppSettingsRepository.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastStreakIso = repo.dailyStreakLastDateIso();
    int newStreak = state.streakDays;

    if (lastStreakIso != null && lastStreakIso.isNotEmpty) {
      final lastStreakDate = DateTime.tryParse(lastStreakIso);
      if (lastStreakDate != null) {
        final lastDay = DateTime(lastStreakDate.year, lastStreakDate.month, lastStreakDate.day);
        final diff = today.difference(lastDay).inDays;
        if (diff == 1) {
          newStreak += 1;
        } else if (diff == 0) {
          // Already checked in today
        } else {
          newStreak = 1;
        }
      }
    } else {
      newStreak = 1;
    }

    state = DailyCheckInState(
      lastCheckInDate: today,
      mood: mood,
      streakDays: newStreak,
      isCheckedInToday: true,
    );

    await repo.setDailyCheckIn(
      dateIso: today.toIso8601String(),
      mood: mood,
      streak: newStreak,
    );
  }

  Future<void> recordAwarenessActivity() async {
    if (state.isCheckedInToday) return;
    final repo = AppSettingsRepository.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await repo.recordDailyStreakActivity(today.toIso8601String());
    state = state.copyWith(streakDays: state.streakDays);
  }
}

final dailyCheckInProvider =
    StateNotifierProvider<DailyCheckInNotifier, DailyCheckInState>((ref) {
  return DailyCheckInNotifier();
});
