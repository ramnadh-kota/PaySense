import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Represents a physical or financial asset held by the user.
@immutable
class Asset {
  /// Creates an immutable asset.
  const Asset({
    required this.id,
    required this.assetType,
    required this.name,
    required this.currentValue,
  });

  /// Unique identifier for the asset.
  final String id;

  /// Type of asset.
  final String assetType;

  /// Display name of the asset.
  final String name;

  /// Current market or book value of the asset.
  final double currentValue;

  /// Creates a copy of this asset with the provided values.
  Asset copyWith({
    String? id,
    String? assetType,
    String? name,
    double? currentValue,
  }) {
    return Asset(
      id: id ?? this.id,
      assetType: assetType ?? this.assetType,
      name: name ?? this.name,
      currentValue: currentValue ?? this.currentValue,
    );
  }

  /// Converts the model to a Map for persistence or transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'assetType': assetType,
      'name': name,
      'currentValue': currentValue,
    };
  }

  /// Creates a model from a Map.
  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'] as String,
      assetType: map['assetType'] as String,
      name: map['name'] as String,
      currentValue: (map['currentValue'] as num).toDouble(),
    );
  }

  /// Converts the model to a JSON string.
  String toJson() => jsonEncode(toMap());

  /// Creates a model from a JSON string.
  factory Asset.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return Asset.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Asset &&
        other.id == id &&
        other.assetType == assetType &&
        other.name == name &&
        other.currentValue == currentValue;
  }

  @override
  int get hashCode => Object.hash(id, assetType, name, currentValue);
}
