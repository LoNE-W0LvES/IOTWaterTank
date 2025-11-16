import 'package:equatable/equatable.dart';

/// Represents a single control data field
class ControlData extends Equatable {
  final String key;
  final String label;
  final String type; // 'boolean', 'number', 'string'
  final dynamic value;
  final dynamic defaultValue;
  final int? lastModified; // Unix timestamp in milliseconds
  final bool system; // True for system flags like config_update

  const ControlData({
    required this.key,
    required this.type,
    required this.value,
    String? label,
    dynamic defaultValue,
    this.lastModified,
    this.system = false,
  })  : label = label ?? key,
        defaultValue = defaultValue ?? value;

  /// Create from JSON
  factory ControlData.fromJson(String key, Map<String, dynamic> json) {
    // Parse lastModified - handle int, string (Unix timestamp), and ISO date string
    int? lastModified;
    final lastModifiedValue = json['lastModified'];
    if (lastModifiedValue != null) {
      if (lastModifiedValue is int) {
        lastModified = lastModifiedValue;
      } else if (lastModifiedValue is String) {
        // Try parsing as Unix timestamp first
        lastModified = int.tryParse(lastModifiedValue);
        // If that fails, try parsing as ISO date string
        if (lastModified == null) {
          try {
            final dateTime = DateTime.parse(lastModifiedValue);
            lastModified = dateTime.millisecondsSinceEpoch;
          } catch (e) {
            // If parsing fails, leave as null
            lastModified = null;
          }
        }
      }
    }

    return ControlData(
      key: key,
      label: json['label'] as String? ?? key,
      type: json['type'] as String,
      value: json['value'],
      defaultValue: json['defaultValue'] ?? json['value'],
      lastModified: lastModified,
      system: json['system'] as bool? ?? false,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'type': type,
      'value': value,
      'defaultValue': defaultValue,
      if (lastModified != null) 'lastModified': lastModified,
      if (system) 'system': system,
    };
  }

  /// Create a copy with updated value
  ControlData copyWith({
    String? key,
    String? label,
    String? type,
    dynamic value,
    dynamic defaultValue,
    int? lastModified,
    bool? system,
  }) {
    return ControlData(
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      value: value ?? this.value,
      defaultValue: defaultValue ?? this.defaultValue,
      lastModified: lastModified ?? this.lastModified,
      system: system ?? this.system,
    );
  }

  /// Create a copy with new value and timestamp
  ControlData withNewValue(dynamic newValue) {
    return copyWith(
      value: newValue,
      defaultValue: newValue,
      lastModified: DateTime.now().millisecondsSinceEpoch,
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
  List<Object?> get props => [key, label, type, value, defaultValue, lastModified, system];

  @override
  String toString() =>
      'ControlData(key: $key, type: $type, value: $value, lastModified: $lastModified)';
}
