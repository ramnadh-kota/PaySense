// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 0;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      id: fields[0] as String,
      fullName: fields[1] as String,
      monthlyIncome: fields[2] as double,
      monthlyEmi: fields[3] as double,
      savingsGoal: fields[4] as double,
      targetDate: fields[5] as DateTime,
      onboardingCompleted: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.monthlyIncome)
      ..writeByte(3)
      ..write(obj.monthlyEmi)
      ..writeByte(4)
      ..write(obj.savingsGoal)
      ..writeByte(5)
      ..write(obj.targetDate)
      ..writeByte(6)
      ..write(obj.onboardingCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
