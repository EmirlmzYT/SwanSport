enum ConfigurationCategory {
  operational,
  branding,
  legal,
  notifications,
  sports,
  system
}

enum ValidationSeverity { information, warning, critical }

class ConfigurationSetting {
  const ConfigurationSetting({
    required this.id,
    required this.module,
    required this.category,
    required this.label,
    required this.value,
  });
  final String id, module, label, value;
  final ConfigurationCategory category;
  ConfigurationSetting copyWith({String? value}) => ConfigurationSetting(
        id: id,
        module: module,
        category: category,
        label: label,
        value: value ?? this.value,
      );
}

class ConfigurationProfile {
  const ConfigurationProfile({
    required this.id,
    required this.name,
    required this.values,
    this.archived = false,
  });
  final String id, name;
  final Map<String, String> values;
  final bool archived;
  ConfigurationProfile copyWith({String? id, String? name, bool? archived}) =>
      ConfigurationProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        values: values,
        archived: archived ?? this.archived,
      );
}

class ConfigurationHistoryEntry {
  const ConfigurationHistoryEntry({
    required this.settingId,
    required this.previousValue,
    required this.newValue,
    required this.changedBy,
    required this.timestamp,
    this.reason,
  });
  final String settingId, previousValue, newValue, changedBy;
  final DateTime timestamp;
  final String? reason;
}

class ConfigurationValidation {
  const ConfigurationValidation({
    required this.settingId,
    required this.severity,
    required this.message,
  });
  final String settingId, message;
  final ValidationSeverity severity;
}

class ConfigurationHealth {
  const ConfigurationHealth({
    required this.activeSeason,
    required this.branches,
    required this.teams,
    required this.brandingReady,
    required this.notificationsHealthy,
    required this.legalCompliant,
    required this.score,
  });
  final String activeSeason;
  final int branches, teams, score;
  final bool brandingReady, notificationsHealthy, legalCompliant;
}

class ConfigurationPermissions {
  const ConfigurationPermissions({
    required this.canView,
    required this.canEdit,
  });
  final bool canView, canEdit;
}
