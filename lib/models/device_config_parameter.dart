import 'package:equatable/equatable.dart';

/// Represents a single device configuration parameter
class DeviceConfigParameter extends Equatable {
  final String key;
  final String label;
  final String type; // 'string', 'number', 'boolean'
  final dynamic value;
  final dynamic defaultValue;
  final int? lastModified; // Unix timestamp in milliseconds
  final bool system; // True for system flags like config_update

  const DeviceConfigParameter({
    required this.key,
    required this.label,
    required this.type,
    required this.value,
    required this.defaultValue,
    this.lastModified,
    this.system = false,
  });

  /// Create from JSON
  factory DeviceConfigParameter.fromJson(String key, Map<String, dynamic> json) {
    // Parse lastModified - handle both int and string from API
    int? lastModified;
    final lastModifiedValue = json['lastModified'];
    if (lastModifiedValue != null) {
      if (lastModifiedValue is int) {
        lastModified = lastModifiedValue;
      } else if (lastModifiedValue is String) {
        lastModified = int.tryParse(lastModifiedValue);
      }
    }

    return DeviceConfigParameter(
      key: key,
      label: json['label'] as String? ?? key,
      type: json['type'] as String,
      value: json['value'],
      defaultValue: json['defaultValue'],
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

  /// Create a copy with updated fields
  DeviceConfigParameter copyWith({
    String? key,
    String? label,
    String? type,
    dynamic value,
    dynamic defaultValue,
    int? lastModified,
    bool? system,
  }) {
    return DeviceConfigParameter(
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
  DeviceConfigParameter withNewValue(dynamic newValue) {
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
      'DeviceConfigParameter(key: $key, type: $type, value: $value, lastModified: $lastModified)';
}
