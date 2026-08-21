// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaxSettingsAdapter extends TypeAdapter<TaxSettings> {
  @override
  final int typeId = 11;

  @override
  TaxSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxSettings(
      annualGrossIncome: fields[0] as double,
      otherIncome: fields[1] as double,
      regime: fields[2] as String,
      ageBand: fields[3] as String,
      section80C: fields[4] as double,
      section80D: fields[5] as double,
      homeLoanInterest: fields[6] as double,
      hraExemption: fields[7] as double,
      otherEligibleDeductions: fields[8] as double,
      tdsAlreadyDeducted: fields[9] as double,
      isIncomeEstimated: fields[10] as bool,
      updatedAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TaxSettings obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.annualGrossIncome)
      ..writeByte(1)
      ..write(obj.otherIncome)
      ..writeByte(2)
      ..write(obj.regime)
      ..writeByte(3)
      ..write(obj.ageBand)
      ..writeByte(4)
      ..write(obj.section80C)
      ..writeByte(5)
      ..write(obj.section80D)
      ..writeByte(6)
      ..write(obj.homeLoanInterest)
      ..writeByte(7)
      ..write(obj.hraExemption)
      ..writeByte(8)
      ..write(obj.otherEligibleDeductions)
      ..writeByte(9)
      ..write(obj.tdsAlreadyDeducted)
      ..writeByte(10)
      ..write(obj.isIncomeEstimated)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
