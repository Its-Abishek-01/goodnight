/// Features each person turns on or off for themselves.
class PersonalFeatures {
  const PersonalFeatures({
    this.alarm = true,
    this.nightMode = true,
    this.reminders = true,
    this.alertAfter = defaultAlertAfter,
    this.watchBubble = true,
  });

  /// The choices for [alertAfter], in minutes; 0 is off.
  static const alertChoices = [0, 5, 10, 15, 30, 60];
  static const defaultAlertAfter = 15;

  /// Everything on. Used until a person changes anything.
  static const all = PersonalFeatures();

  final bool alarm;
  final bool nightMode;
  final bool reminders;

  /// Push me when my partner has been on their phone this many minutes after
  /// their bedtime (0 = never). Chosen by the person who gets the alert;
  /// the partner can see it.
  final int alertAfter;

  /// The little face on the screen edge over Instagram and Shorts at night,
  /// with how long I have watched and how many reels.
  final bool watchBubble;

  factory PersonalFeatures.fromMap(Map<String, dynamic> m) => PersonalFeatures(
    alarm: m['alarm'] as bool? ?? true,
    nightMode: m['nightMode'] as bool? ?? true,
    reminders: m['reminders'] as bool? ?? true,
    alertAfter: (m['alertAfter'] as num?)?.toInt() ?? defaultAlertAfter,
    watchBubble: m['watchBubble'] as bool? ?? true,
  );

  Map<String, Object> toMap() => {
    'alarm': alarm,
    'nightMode': nightMode,
    'reminders': reminders,
    'alertAfter': alertAfter,
    'watchBubble': watchBubble,
  };

  PersonalFeatures copyWith({
    bool? alarm,
    bool? nightMode,
    bool? reminders,
    int? alertAfter,
    bool? watchBubble,
  }) =>
      PersonalFeatures(
        alarm: alarm ?? this.alarm,
        nightMode: nightMode ?? this.nightMode,
        reminders: reminders ?? this.reminders,
        alertAfter: alertAfter ?? this.alertAfter,
        watchBubble: watchBubble ?? this.watchBubble,
      );

  @override
  bool operator ==(Object other) =>
      other is PersonalFeatures &&
      other.alarm == alarm &&
      other.nightMode == nightMode &&
      other.reminders == reminders &&
      other.alertAfter == alertAfter &&
      other.watchBubble == watchBubble;

  @override
  int get hashCode => Object.hash(alarm, nightMode, reminders, alertAfter, watchBubble);
}

/// Features the couple shares. A change needs one person to propose it and
/// the other to approve it, like a bedtime.
class SharedFeatures {
  const SharedFeatures({this.streak = true, this.moments = true});

  static const all = SharedFeatures();

  /// The shared streak and the coupons it earns.
  final bool streak;

  /// Selfies and the home-screen widget.
  final bool moments;

  factory SharedFeatures.fromMap(Map<String, dynamic> m) => SharedFeatures(
    streak: m['streak'] as bool? ?? true,
    moments: m['moments'] as bool? ?? true,
  );

  Map<String, bool> toMap() => {'streak': streak, 'moments': moments};

  SharedFeatures copyWith({bool? streak, bool? moments}) => SharedFeatures(
    streak: streak ?? this.streak,
    moments: moments ?? this.moments,
  );

  @override
  bool operator ==(Object other) =>
      other is SharedFeatures &&
      other.streak == streak &&
      other.moments == moments;

  @override
  int get hashCode => Object.hash(streak, moments);
}

/// Human-readable list of what a proposal changes, for example
/// "turn off Moments".
String describeChange(SharedFeatures from, SharedFeatures to) {
  String verb(bool on) => on ? 'turn on' : 'turn off';
  return [
    if (from.streak != to.streak) '${verb(to.streak)} Streak & coupons',
    if (from.moments != to.moments) '${verb(to.moments)} Moments',
  ].join(' and ');
}

/// The approved shared features plus a pending change, if any. [by] is the
/// uid of whoever proposed it, so the other person is the one who approves.
class SharedSettings {
  const SharedSettings({
    this.current = SharedFeatures.all,
    this.proposal,
    this.by,
  });

  static const initial = SharedSettings();

  final SharedFeatures current;
  final SharedFeatures? proposal;
  final String? by;

  factory SharedSettings.fromMap(Map<String, dynamic>? d) {
    if (d == null) return initial;
    final cur = d['current'] as Map<String, dynamic>?;
    final prop = d['proposal'] as Map<String, dynamic>?;
    return SharedSettings(
      current: cur == null ? SharedFeatures.all : SharedFeatures.fromMap(cur),
      proposal: prop == null ? null : SharedFeatures.fromMap(prop),
      by: prop?['by'] as String?,
    );
  }
}
