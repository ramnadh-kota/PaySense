// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LoanAdapter extends TypeAdapter<Loan> {
  @override
  final int typeId = 7;

  @override
  Loan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Loan(
      id: fields[0] as String,
      loanName: fields[1] as String,
      lenderName: fields[2] as String,
      loanType: fields[3] as String,
      principalAmount: fields[4] as double,
      interestRate: fields[5] as double,
      tenureMonths: fields[6] as int,
      emiAmount: fields[7] as double,
      outstandingAmount: fields[8] as double,
      paidAmount: fields[9] as double,
      accountId: fields[10] as String,
      nextDueDate: fields[11] as DateTime,
      startDate: fields[12] as DateTime,
      endDate: fields[13] as DateTime,
      totalInterest: fields[14] as double,
      status: fields[15] as String,
      createdAt: fields[16] as DateTime,
      updatedAt: fields[17] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Loan obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.loanName)
      ..writeByte(2)
      ..write(obj.lenderName)
      ..writeByte(3)
      ..write(obj.loanType)
      ..writeByte(4)
      ..write(obj.principalAmount)
      ..writeByte(5)
      ..write(obj.interestRate)
      ..writeByte(6)
      ..write(obj.tenureMonths)
      ..writeByte(7)
      ..write(obj.emiAmount)
      ..writeByte(8)
      ..write(obj.outstandingAmount)
      ..writeByte(9)
      ..write(obj.paidAmount)
      ..writeByte(10)
      ..write(obj.accountId)
      ..writeByte(11)
      ..write(obj.nextDueDate)
      ..writeByte(12)
      ..write(obj.startDate)
      ..writeByte(13)
      ..write(obj.endDate)
      ..writeByte(14)
      ..write(obj.totalInterest)
      ..writeByte(15)
      ..write(obj.status)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
