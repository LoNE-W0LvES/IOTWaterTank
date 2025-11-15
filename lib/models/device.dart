import 'package:equatable/equatable.dart';
import 'control_data.dart';
import 'telemetry_data.dart';

/// Represents an IoT device
class Device extends Equatable {
  final String id;
  final String name;
  final String deviceId;
  final String? description;
  final String? projectId;
  final String? projectName;
  final Map<String, ControlData> controlData;
  final Map<String, TelemetryData> telemetryData;
  final bool isActive;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Device({
    required this.id,
    required this.name,
    required this.deviceId,
    this.description,
    this.projectId,
    this.projectName,
    this.controlData = const {},
    this.telemetryData = const {},
    this.isActive = false,
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from JSON
  factory Device.fromJson(Map<String, dynamic> json) {
    // Parse control data
    final Map<String, ControlData> controls = {};
    final controlDataJson = json['controlData'] as Map<String, dynamic>?;
    if (controlDataJson != null) {
      controlDataJson.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          controls[key] = ControlData.fromJson(key, value);
        }
      });
    }

    // Parse telemetry data
    final Map<String, TelemetryData> telemetry = {};
    final telemetryDataJson = json['telemetryData'] as Map<String, dynamic>?;
    if (telemetryDataJson != null) {
      telemetryDataJson.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          telemetry[key] = TelemetryData.fromJson(key, value);
        }
      });
    }

    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceId: json['deviceId'] as String,
      description: json['description'] as String?,
      projectId: json['projectId'] as String?,
      projectName: json['projectName'] as String?,
      controlData: controls,
      telemetryData: telemetry,
      isActive: json['isActive'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'deviceId': deviceId,
      if (description != null) 'description': description,
      if (projectId != null) 'projectId': projectId,
      if (projectName != null) 'projectName': projectName,
      'controlData': controlData.map(
        (key, value) => MapEntry(key, {
          'type': value.type,
          'value': value.value,
        }),
      ),
      'telemetryData': telemetry.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'isActive': isActive,
      if (lastSeen != null) 'lastSeen': lastSeen!.toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Shorthand for telemetryData
  Map<String, TelemetryData> get telemetry => telemetryData;

  /// Get user-controllable control data (exclude system flags)
  Map<String, ControlData> getUserControls() {
    return Map.fromEntries(
      controlData.entries.where(
        (entry) => !['force_update', 'config_update'].contains(entry.key),
      ),
    );
  }

  /// Get system control flags
  Map<String, ControlData> getSystemControls() {
    return Map.fromEntries(
      controlData.entries.where(
        (entry) => ['force_update', 'config_update'].contains(entry.key),
      ),
    );
  }

  /// Get status color based on device state
  String getStatusColor() {
    if (!isActive) return 'grey';
    if (lastSeen == null) return 'grey';

    final now = DateTime.now();
    final difference = now.difference(lastSeen!).inSeconds;

    if (difference < 60) return 'green'; // Active in last minute
    if (difference < 300) return 'yellow'; // Active in last 5 minutes
    return 'red'; // Inactive
  }

  /// Get human-readable status
  String getStatusText() {
    if (!isActive) return 'Inactive';
    if (lastSeen == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(lastSeen!);

    if (difference.inSeconds < 60) {
      return 'Active (${difference.inSeconds}s ago)';
    } else if (difference.inMinutes < 60) {
      return 'Active (${difference.inMinutes}m ago)';
    } else if (difference.inHours < 24) {
      return 'Active (${difference.inHours}h ago)';
    } else {
      return 'Active (${difference.inDays}d ago)';
    }
  }

  /// Create a copy with updated fields
  Device copyWith({
    String? id,
    String? name,
    String? deviceId,
    String? description,
    String? projectId,
    String? projectName,
    Map<String, ControlData>? controlData,
    Map<String, TelemetryData>? telemetryData,
    bool? isActive,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      description: description ?? this.description,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      controlData: controlData ?? this.controlData,
      telemetryData: telemetryData ?? this.telemetryData,
      isActive: isActive ?? this.isActive,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        deviceId,
        description,
        projectId,
        projectName,
        controlData,
        telemetryData,
        isActive,
        lastSeen,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() => 'Device(id: $id, name: $name, deviceId: $deviceId)';
}
