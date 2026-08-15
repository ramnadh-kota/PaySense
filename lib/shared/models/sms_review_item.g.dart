// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sms_review_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SmsReviewItemAdapter extends TypeAdapter<SmsReviewItem> {
  @override
  final int typeId = 10;

  @override
  SmsReviewItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SmsReviewItem(
      id: fields[0] as String,
      amount: fields[1] as double,
      directionKey: fields[2] as String,
      sender: fields[3] as String,
      timestamp: fields[4] as DateTime,
      confidence: fields[5] as double,
      isLikelyTransfer: fields[6] as bool,
      statusKey: fields[7] as String,
      createdAt: fields[8] as DateTime,
      merchant: fields[9] as String?,
      suggestedWalletId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SmsReviewItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.directionKey)
      ..writeByte(3)
      ..write(obj.sender)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.confidence)
      ..writeByte(6)
      ..write(obj.isLikelyTransfer)
      ..writeByte(7)
      ..write(obj.statusKey)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.merchant)
      ..writeByte(10)
      ..write(obj.suggestedWalletId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmsReviewItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
