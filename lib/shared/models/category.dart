import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Represents a spending or income category.
@immutable
class Category {
  /// Creates an immutable category.
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  /// Unique identifier for the category.
  final String id;

  /// Display name of the category.
  final String name;

  /// Icon identifier used by the UI.
  final String icon;

  /// Color code used by the UI.
  final String color;

  /// Category type, either income or expense.
  final String type;

  /// Creates a copy of this category with the provided values.
  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    String? type,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
    );
  }

  /// Converts the model to a Map for persistence or transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type,
    };
  }

  /// Creates a model from a Map.
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      type: map['type'] as String,
    );
  }

  /// Converts the model to a JSON string.
  String toJson() => jsonEncode(toMap());

  /// Creates a model from a JSON string.
  factory Category.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return Category.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.icon == icon &&
        other.color == color &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, name, icon, color, type);
}
