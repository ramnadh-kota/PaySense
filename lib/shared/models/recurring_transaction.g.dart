// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurringTransactionAdapter extends TypeAdapter<RecurringTransaction> {
  @override
  final int typeId = 5;

  @override
  RecurringTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringTransaction(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      categoryId: fields[3] as String,
      accountId: fields[4] as String,
      transactionType: fields[5] as String,
      frequency: fields[6] as String,
      startDate: fields[7] as DateTime,
      nextDueDate: fields[8] as DateTime,
      endDate: fields[9] as DateTime?,
      lastGeneratedDate: fields[10] as DateTime?,
      isActive: fields[11] as bool,
      reminderDaysBefore: fields[12] as int,
      note: fields[13] as String,
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringTransaction obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.accountId)
      ..writeByte(5)
      ..write(obj.transactionType)
      ..writeByte(6)
      ..write(obj.frequency)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.nextDueDate)
      ..writeByte(9)
      ..write(obj.endDate)
      ..writeByte(10)
      ..write(obj.lastGeneratedDate)
      ..writeByte(11)
      ..write(obj.isActive)
      ..writeByte(12)
      ..write(obj.reminderDaysBefore)
      ..writeByte(13)
      ..write(obj.note)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
