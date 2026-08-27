// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fun_group_expense.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FunGroupParticipantAdapter extends TypeAdapter<FunGroupParticipant> {
  @override
  final int typeId = 13;

  @override
  FunGroupParticipant read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FunGroupParticipant(
      id: fields[0] as String,
      name: fields[1] as String,
      shareAmount: fields[2] as double,
      isSettled: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, FunGroupParticipant obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.shareAmount)
      ..writeByte(3)
      ..write(obj.isSettled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FunGroupParticipantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FunGroupExpenseAdapter extends TypeAdapter<FunGroupExpense> {
  @override
  final int typeId = 12;

  @override
  FunGroupExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FunGroupExpense(
      id: fields[0] as String,
      title: fields[1] as String,
      categoryKey: fields[2] as String,
      totalAmount: fields[3] as double,
      date: fields[4] as DateTime,
      paidByParticipantId: fields[5] as String,
      participants: (fields[6] as List).cast<FunGroupParticipant>(),
      createdAt: fields[7] as DateTime,
      note: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FunGroupExpense obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.categoryKey)
      ..writeByte(3)
      ..write(obj.totalAmount)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.paidByParticipantId)
      ..writeByte(6)
      ..write(obj.participants)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FunGroupExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
