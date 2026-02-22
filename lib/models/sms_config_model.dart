class SmsConfigModel {
  // Scheduler time
  final int dailyHour;
  final int dailyMinute;

  // Global toggles
  final bool smsEnabled;
  final String? smsEnabledDeviceId;
  final bool smsForVisits;
  final bool smsForPayments;
  final bool smsForPrescriptions;
  final String smsLanguage;
  final String opticaName;
  final String opticaPhone;
  final Map<String, String> smsTemplatesLatin;
  final Map<String, String> smsTemplatesCyrillic;
  final String prescriptionItemTemplateLatin;
  final String prescriptionItemTemplateCyrillic;

  // Visit rules
  final bool visitSendOnCreate;
  final bool visitSendBefore;
  final int visitDaysBefore;
  final bool visitSendOnDate;
  final int visitMaxCount;

  // Debt rules
  final bool debtSendOnCreate;
  final bool debtSendBefore;
  final int debtDaysBefore;
  final bool debtSendOnDueDate;
  final bool debtRepeatEnabled;
  final int debtRepeatDays;
  final int debtMaxCount;

  const SmsConfigModel({
    required this.dailyHour,
    required this.dailyMinute,
    required this.smsEnabled,
    required this.smsEnabledDeviceId,
    required this.smsForVisits,
    required this.smsForPayments,
    required this.smsForPrescriptions,
    required this.smsLanguage,
    this.opticaName = 'Optica',
    this.opticaPhone = '',
    this.smsTemplatesLatin = const {},
    this.smsTemplatesCyrillic = const {},
    this.prescriptionItemTemplateLatin = '',
    this.prescriptionItemTemplateCyrillic = '',
    required this.visitSendOnCreate,
    required this.visitSendBefore,
    required this.visitDaysBefore,
    required this.visitSendOnDate,
    required this.visitMaxCount,
    required this.debtSendOnCreate,
    required this.debtSendBefore,
    required this.debtDaysBefore,
    required this.debtSendOnDueDate,
    required this.debtRepeatEnabled,
    required this.debtRepeatDays,
    required this.debtMaxCount,
  });

  bool get isSmsEnabled => smsEnabled || smsEnabledDeviceId != null;
  bool get isSmsCyrillic => smsLanguage == languageCyrillic;

  static const String languageLatin = 'latin';
  static const String languageCyrillic = 'cyrillic';

  factory SmsConfigModel.fromMap(Map<String, dynamic> data) {
    final deviceId = data['smsEnabledDeviceId'] as String?;
    final enabled = data['smsEnabled'] ?? (deviceId != null);
    final rawLanguage = (data['smsLanguage'] as String?)?.toLowerCase();
    final normalizedLanguage =
        rawLanguage == languageLatin ? languageLatin : languageCyrillic;
    final hasNewDebtRepeat = data.containsKey('smsDebtRepeatEnabled') ||
        data.containsKey('smsDebtRepeatDays');
    final opticaName = (data['name'] ?? 'Optica').toString().trim();
    final opticaPhone = (data['phone'] ?? '').toString().trim();
    final templatesLatin = _stringMap(data['smsTemplatesLatin']);
    final templatesCyrillic = _stringMap(data['smsTemplatesCyrillic']);
    final prescriptionItemTemplateLatin =
        (data['smsPrescriptionItemTemplateLatin'] ?? '').toString();
    final prescriptionItemTemplateCyrillic =
        (data['smsPrescriptionItemTemplateCyrillic'] ?? '').toString();

    return SmsConfigModel(
      dailyHour: _toInt(data['smsDailyHour'], fallback: 9, min: 0, max: 23),
      dailyMinute: _toInt(data['smsDailyMinute'], fallback: 0, min: 0, max: 59),
      smsEnabled: enabled == true,
      smsEnabledDeviceId: deviceId,
      smsForVisits: data['smsForVisits'] ?? true,
      smsForPayments: data['smsForPayments'] ?? true,
      smsForPrescriptions: data['smsForPrescriptions'] ?? true,
      smsLanguage: normalizedLanguage,
      opticaName: opticaName.isEmpty ? 'Optica' : opticaName,
      opticaPhone: opticaPhone,
      smsTemplatesLatin: templatesLatin,
      smsTemplatesCyrillic: templatesCyrillic,
      prescriptionItemTemplateLatin: prescriptionItemTemplateLatin,
      prescriptionItemTemplateCyrillic: prescriptionItemTemplateCyrillic,
      visitSendOnCreate: data['smsVisitOnCreate'] ?? true,
      visitSendBefore: data['smsVisitBeforeEnabled'] ?? true,
      visitDaysBefore: _toInt(data['smsVisitDaysBefore'], fallback: 1, min: 0, max: 365),
      visitSendOnDate: data['smsVisitOnDate'] ?? true,
      visitMaxCount: _toInt(data['smsVisitMaxCount'], fallback: 3, min: 0, max: 100),
      debtSendOnCreate: data['smsDebtOnCreate'] ?? false,
      debtSendBefore: data['smsDebtBeforeEnabled'] ?? false,
      debtDaysBefore: _toInt(data['smsDebtDaysBefore'], fallback: 1, min: 1, max: 365),
      debtSendOnDueDate: data['smsDebtOnDueDate'] ?? true,
      debtRepeatEnabled: data['smsDebtRepeatEnabled'] ??
          (hasNewDebtRepeat ? false : (data['smsDebtAfter1Enabled'] ?? false)),
      debtRepeatDays: _toInt(
        data['smsDebtRepeatDays'] ??
            (hasNewDebtRepeat ? null : data['smsDebtAfterDays1']),
        fallback: 3,
        min: 1,
        max: 365,
      ),
      debtMaxCount: _toInt(data['smsDebtMaxCount'], fallback: 3, min: 0, max: 100),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'smsDailyHour': dailyHour,
      'smsDailyMinute': dailyMinute,
      'smsForVisits': smsForVisits,
      'smsForPayments': smsForPayments,
      'smsForPrescriptions': smsForPrescriptions,
      'smsLanguage': smsLanguage,
      'smsVisitOnCreate': visitSendOnCreate,
      'smsVisitBeforeEnabled': visitSendBefore,
      'smsVisitDaysBefore': visitDaysBefore,
      'smsVisitOnDate': visitSendOnDate,
      'smsVisitMaxCount': visitMaxCount,
      'smsDebtOnCreate': debtSendOnCreate,
      'smsDebtBeforeEnabled': debtSendBefore,
      'smsDebtDaysBefore': debtDaysBefore,
      'smsDebtOnDueDate': debtSendOnDueDate,
      'smsDebtRepeatEnabled': debtRepeatEnabled,
      'smsDebtRepeatDays': debtRepeatDays,
      'smsDebtMaxCount': debtMaxCount,
    };
  }

  SmsConfigModel copyWith({
    int? dailyHour,
    int? dailyMinute,
    bool? smsEnabled,
    String? smsEnabledDeviceId,
    bool? smsForVisits,
    bool? smsForPayments,
    bool? smsForPrescriptions,
    String? smsLanguage,
    String? opticaName,
    String? opticaPhone,
    Map<String, String>? smsTemplatesLatin,
    Map<String, String>? smsTemplatesCyrillic,
    String? prescriptionItemTemplateLatin,
    String? prescriptionItemTemplateCyrillic,
    bool? visitSendOnCreate,
    bool? visitSendBefore,
    int? visitDaysBefore,
    bool? visitSendOnDate,
    int? visitMaxCount,
    bool? debtSendOnCreate,
    bool? debtSendBefore,
    int? debtDaysBefore,
    bool? debtSendOnDueDate,
    bool? debtRepeatEnabled,
    int? debtRepeatDays,
    int? debtMaxCount,
  }) {
    return SmsConfigModel(
      dailyHour: dailyHour ?? this.dailyHour,
      dailyMinute: dailyMinute ?? this.dailyMinute,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      smsEnabledDeviceId: smsEnabledDeviceId ?? this.smsEnabledDeviceId,
      smsForVisits: smsForVisits ?? this.smsForVisits,
      smsForPayments: smsForPayments ?? this.smsForPayments,
      smsForPrescriptions: smsForPrescriptions ?? this.smsForPrescriptions,
      smsLanguage: smsLanguage ?? this.smsLanguage,
      opticaName: opticaName ?? this.opticaName,
      opticaPhone: opticaPhone ?? this.opticaPhone,
      smsTemplatesLatin: smsTemplatesLatin ?? this.smsTemplatesLatin,
      smsTemplatesCyrillic: smsTemplatesCyrillic ?? this.smsTemplatesCyrillic,
      prescriptionItemTemplateLatin:
          prescriptionItemTemplateLatin ?? this.prescriptionItemTemplateLatin,
      prescriptionItemTemplateCyrillic: prescriptionItemTemplateCyrillic ??
          this.prescriptionItemTemplateCyrillic,
      visitSendOnCreate: visitSendOnCreate ?? this.visitSendOnCreate,
      visitSendBefore: visitSendBefore ?? this.visitSendBefore,
      visitDaysBefore: visitDaysBefore ?? this.visitDaysBefore,
      visitSendOnDate: visitSendOnDate ?? this.visitSendOnDate,
      visitMaxCount: visitMaxCount ?? this.visitMaxCount,
      debtSendOnCreate: debtSendOnCreate ?? this.debtSendOnCreate,
      debtSendBefore: debtSendBefore ?? this.debtSendBefore,
      debtDaysBefore: debtDaysBefore ?? this.debtDaysBefore,
      debtSendOnDueDate: debtSendOnDueDate ?? this.debtSendOnDueDate,
      debtRepeatEnabled: debtRepeatEnabled ?? this.debtRepeatEnabled,
      debtRepeatDays: debtRepeatDays ?? this.debtRepeatDays,
      debtMaxCount: debtMaxCount ?? this.debtMaxCount,
    );
  }

  static int _toInt(
    dynamic value, {
    required int fallback,
    required int min,
    required int max,
  }) {
    int parsed;
    if (value is int) {
      parsed = value;
    } else if (value is num) {
      parsed = value.toInt();
    } else if (value is String) {
      parsed = int.tryParse(value) ?? fallback;
    } else {
      parsed = fallback;
    }

    if (parsed < min) return min;
    if (parsed > max) return max;
    return parsed;
  }

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw.map((key, value) => MapEntry(
            key.toString(),
            value?.toString() ?? '',
          ));
    }
    return {};
  }
}
