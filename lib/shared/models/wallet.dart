import 'package:hive/hive.dart';

part 'wallet.g.dart';

@HiveType(typeId: 1)
class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.bankName,
    required this.type,
    required this.openingBalance,
    required this.currentBalance,
    required this.createdAt,
  });
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String bankName;
  @HiveField(3)
  final String type;
  @HiveField(4)
  final double openingBalance;
  @HiveField(5)
  final double currentBalance;
  @HiveField(6)
  final DateTime createdAt;

  Wallet copyWith({
    String? id,
    String? name,
    String? bankName,
    String? type,
    double? openingBalance,
    double? currentBalance,
    DateTime? createdAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      bankName: bankName ?? this.bankName,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'bankName': bankName,
      'type': type,
      'openingBalance': openingBalance,
      'currentBalance': currentBalance,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map['id'] as String,
      name: map['name'] as String,
      bankName: map['bankName'] as String,
      type: map['type'] as String,
      openingBalance: (map['openingBalance'] as num).toDouble(),
      currentBalance: (map['currentBalance'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
