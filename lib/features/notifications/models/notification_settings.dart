class NotificationSettings {
  final bool scheduleAdded;
  final bool scheduleDeleted;
  final bool scheduleUpdated;
  final bool commentAdded;
  final bool partnerCommuteAlerts;
  final bool bothOff;
  final bool dateBefore;
  final bool dateToday;
  final bool diagnosticLogs;

  const NotificationSettings({
    this.scheduleAdded = true,
    this.scheduleDeleted = true,
    this.scheduleUpdated = true,
    this.commentAdded = true,
    this.partnerCommuteAlerts = true,
    this.bothOff = true,
    this.dateBefore = true,
    this.dateToday = true,
    this.diagnosticLogs = false,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      scheduleAdded: json['schedule_added'] as bool? ?? true,
      scheduleDeleted: json['schedule_deleted'] as bool? ?? true,
      scheduleUpdated: json['schedule_updated'] as bool? ?? true,
      commentAdded: json['comment_added'] as bool? ?? true,
      partnerCommuteAlerts: json['partner_commute_alerts'] as bool? ?? true,
      bothOff: json['both_off'] as bool? ?? true,
      dateBefore: json['date_before'] as bool? ?? true,
      dateToday: json['date_today'] as bool? ?? true,
      diagnosticLogs: json['diagnostic_logs'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'schedule_added': scheduleAdded,
        'schedule_deleted': scheduleDeleted,
        'schedule_updated': scheduleUpdated,
        'comment_added': commentAdded,
        'partner_commute_alerts': partnerCommuteAlerts,
        'both_off': bothOff,
        'date_before': dateBefore,
        'date_today': dateToday,
        'diagnostic_logs': diagnosticLogs,
      };

  NotificationSettings copyWith({
    bool? scheduleAdded,
    bool? scheduleDeleted,
    bool? scheduleUpdated,
    bool? commentAdded,
    bool? partnerCommuteAlerts,
    bool? bothOff,
    bool? dateBefore,
    bool? dateToday,
    bool? diagnosticLogs,
  }) {
    return NotificationSettings(
      scheduleAdded: scheduleAdded ?? this.scheduleAdded,
      scheduleDeleted: scheduleDeleted ?? this.scheduleDeleted,
      scheduleUpdated: scheduleUpdated ?? this.scheduleUpdated,
      commentAdded: commentAdded ?? this.commentAdded,
      partnerCommuteAlerts: partnerCommuteAlerts ?? this.partnerCommuteAlerts,
      bothOff: bothOff ?? this.bothOff,
      dateBefore: dateBefore ?? this.dateBefore,
      dateToday: dateToday ?? this.dateToday,
      diagnosticLogs: diagnosticLogs ?? this.diagnosticLogs,
    );
  }
}
