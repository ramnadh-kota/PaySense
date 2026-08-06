// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BudgetAdapter extends TypeAdapter<Budget> {
  @override
  final int typeId = 3;

  @override
  Budget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Budget(
      id: fields[0] as String,
      categoryId: fields[1] as String,
      categoryName: fields[2] as String,
      allocatedAmount: fields[3] as double,
      spentAmount: fields[4] as double,
      remainingAmount: fields[5] as double,
      percentageUsed: fields[6] as double,
      month: fields[7] as String,
      year: fields[8] as int,
      createdAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Budget obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.categoryName)
      ..writeByte(3)
      ..write(obj.allocatedAmount)
      ..writeByte(4)
      ..write(obj.spentAmount)
      ..writeByte(5)
      ..write(obj.remainingAmount)
      ..writeByte(6)
      ..write(obj.percentageUsed)
      ..writeByte(7)
      ..write(obj.month)
      ..writeByte(8)
      ..write(obj.year)
      ..writeByte(9)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
