import 'package:equatable/equatable.dart';

/// Represents a single control data field
class ControlData extends Equatable {
  final String key;
  final String type; // 'boolean', 'number', 'string'
  final dynamic value;

  const ControlData({
    required this.key,
    required this.type,
    required this.value,
  });

  /// Create from JSON
  factory ControlData.fromJson(String key, Map<String, dynamic> json) {
    return ControlData(
      key: key,
      type: json['type'] as String,
      value: json['value'],
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'type': type,
      'value': value,
    };
  }

  /// Create a copy with updated value
  ControlData copyWith({
    String? key,
    String? type,
    dynamic value,
  }) {
    return ControlData(
      key: key ?? this.key,
      type: type ?? this.type,
      value: value ?? this.value,
    );
  }

  /// Get value as boolean (with fallback)
  bool get boolValue => value is bool ? value as bool : false;

  /// Get value as number (with fallback)
  double get numberValue {
    if (value is num) return (value as num).toDouble();
    return 0.0;
  }

  /// Get value as string
  String get stringValue => value?.toString() ?? '';

  @override
  List<Object?> get props => [key, type, value];

  @override
  String toString() => 'ControlData(key: $key, type: $type, value: $value)';
}
