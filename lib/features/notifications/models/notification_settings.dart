class NotificationSettings {
  final bool scheduleAdded;
  final bool scheduleDeleted;
  final bool scheduleUpdated;
  final bool bothOff;
  final bool dateBefore;
  final bool dateToday;

  const NotificationSettings({
    this.scheduleAdded = true,
    this.scheduleDeleted = true,
    this.scheduleUpdated = true,
    this.bothOff = true,
    this.dateBefore = true,
    this.dateToday = true,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      scheduleAdded: json['schedule_added'] as bool? ?? true,
      scheduleDeleted: json['schedule_deleted'] as bool? ?? true,
      scheduleUpdated: json['schedule_updated'] as bool? ?? true,
      bothOff: json['both_off'] as bool? ?? true,
      dateBefore: json['date_before'] as bool? ?? true,
      dateToday: json['date_today'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule_added': scheduleAdded,
      'schedule_deleted': scheduleDeleted,
      'schedule_updated': scheduleUpdated,
      'both_off': bothOff,
      'date_before': dateBefore,
      'date_today': dateToday,
    };
  }

  NotificationSettings copyWith({
    bool? scheduleAdded,
    bool? scheduleDeleted,
    bool? scheduleUpdated,
    bool? bothOff,
    bool? dateBefore,
    bool? dateToday,
  }) {
    return NotificationSettings(
      scheduleAdded: scheduleAdded ?? this.scheduleAdded,
      scheduleDeleted: scheduleDeleted ?? this.scheduleDeleted,
      scheduleUpdated: scheduleUpdated ?? this.scheduleUpdated,
      bothOff: bothOff ?? this.bothOff,
      dateBefore: dateBefore ?? this.dateBefore,
      dateToday: dateToday ?? this.dateToday,
    );
  }

  void toggleAll() {
    final newValue = !scheduleAdded;
    NotificationSettings(
      scheduleAdded: newValue,
      scheduleDeleted: newValue,
      scheduleUpdated: newValue,
      bothOff: newValue,
      dateBefore: newValue,
      dateToday: newValue,
    );
  }
}
