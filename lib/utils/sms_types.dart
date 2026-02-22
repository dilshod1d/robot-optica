class SmsLogTypes {
  // Visit stages
  static const String visitCreated = 'visit-created';
  static const String visitBefore = 'visit-before';
  static const String visitOnDate = 'visit-on-date';

  // Debt stages
  static const String debtCreated = 'debt-created';
  static const String debtBefore = 'debt-before';
  static const String debtDue = 'debt-due';
  static const String debtRepeat = 'debt-repeat';
  static const String debtPaid = 'debt-paid';
  // Legacy debt stages
  static const String debtAfter1 = 'debt-after-1';
  static const String debtAfter2 = 'debt-after-2';

  // Prescription stages
  static const String prescriptionCreated = 'prescription-created';

  // Marketing
  static const String marketing = 'marketing';

  // Legacy types (kept for stats/backward compat)
  static const String legacyVisit = 'visit';
  static const String legacyVisitFinal = 'visit-final';
  static const String legacyDebt = 'debt';
  static const String legacyPrescription = 'prescription';

  static const List<String> visitTypes = [
    visitCreated,
    visitBefore,
    visitOnDate,
    legacyVisit,
    legacyVisitFinal,
  ];

  static const List<String> debtTypes = [
    debtCreated,
    debtBefore,
    debtDue,
    debtRepeat,
    debtPaid,
    debtAfter1,
    debtAfter2,
    legacyDebt,
  ];

  static const List<String> prescriptionTypes = [
    prescriptionCreated,
    legacyPrescription,
  ];

  static const List<String> marketingTypes = [
    marketing,
  ];
}
