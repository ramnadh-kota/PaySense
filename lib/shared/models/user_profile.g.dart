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
      email: fields[2] as String,
      phone: fields[3] as String,
      dateOfBirth: fields[4] as DateTime?,
      gender: fields[5] as String,
      occupation: fields[6] as String,
      monthlyIncome: fields[7] as double,
      currency: fields[8] as String,
      country: fields[9] as String,
      monthlyEmi: fields[10] as double,
      savingsGoal: fields[11] as double,
      createdAt: fields[12] as DateTime,
      updatedAt: fields[13] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.dateOfBirth)
      ..writeByte(5)
      ..write(obj.gender)
      ..writeByte(6)
      ..write(obj.occupation)
      ..writeByte(7)
      ..write(obj.monthlyIncome)
      ..writeByte(8)
      ..write(obj.currency)
      ..writeByte(9)
      ..write(obj.country)
      ..writeByte(10)
      ..write(obj.monthlyEmi)
      ..writeByte(11)
      ..write(obj.savingsGoal)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt);
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
