import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/billing_status_helper.dart';
import './billing_status.dart';


class BillingModel {
  final String id;
  final String opticaId;
  final String customerId;
  final String customerName;

  final double amountDue;
  final double amountPaid;

  final Timestamp dueDate;
  final int reminderSentCount;
  final bool debtSmsPending;
  final bool debtPaidSmsPending;
  final DateTime? debtSmsResetAt;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  BillingModel({
    required this.id,
    required this.opticaId,
    required this.customerId,
    required this.customerName,
    required this.amountDue,
    required this.amountPaid,
    required this.dueDate,
    this.reminderSentCount = 0,
    this.debtSmsPending = false,
    this.debtPaidSmsPending = false,
    this.debtSmsResetAt,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remaining => amountDue - amountPaid;

  /// 🔥 LIVE status (always correct)
  BillingStatus get liveStatus {
    return calculateBillingStatus(
      amountDue: amountDue,
      amountPaid: amountPaid,
      dueDate: dueDate,
        updatedAt: updatedAt
    );
  }

  bool get isOverdue {
    final now = DateTime.now();
    return remaining > 0 && dueDate.toDate().isBefore(now);
  }


  factory BillingModel.fromFirestore(DocumentSnapshot doc, String opticaId) {
    final data = doc.data() as Map<String, dynamic>;

    return BillingModel(
      id: doc.id,
      opticaId: opticaId,
      customerId: data['customerId'],
      customerName: data['customerName'],
      amountDue: (data['amountDue'] as num).toDouble(),
      amountPaid: (data['amountPaid'] as num).toDouble(),
      dueDate: data['dueDate'],
      reminderSentCount: (data['reminderSentCount'] ?? 0) as int,
      debtSmsPending: (data['debtSmsPending'] ?? false) as bool,
      debtPaidSmsPending: (data['debtPaidSmsPending'] ?? false) as bool,
      debtSmsResetAt: data['debtSmsResetAt'] != null
          ? (data['debtSmsResetAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'amountDue': amountDue,
      'amountPaid': amountPaid,
      'dueDate': dueDate,
      'reminderSentCount': reminderSentCount,
      'debtSmsPending': debtSmsPending,
      'debtPaidSmsPending': debtPaidSmsPending,
      'debtSmsResetAt':
          debtSmsResetAt != null ? Timestamp.fromDate(debtSmsResetAt!) : null,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
  BillingModel copyWith({
    double? amountPaid,
    int? reminderSentCount,
    bool? debtSmsPending,
    bool? debtPaidSmsPending,
    DateTime? debtSmsResetAt,
    Timestamp? updatedAt,
    Timestamp? dueDate,
  }) {
    return BillingModel(
      id: id,
      opticaId: opticaId,
      customerId: customerId,
      customerName: customerName,
      amountDue: amountDue,
      amountPaid: amountPaid ?? this.amountPaid,
      reminderSentCount: reminderSentCount ?? this.reminderSentCount,
      debtSmsPending: debtSmsPending ?? this.debtSmsPending,
      debtPaidSmsPending: debtPaidSmsPending ?? this.debtPaidSmsPending,
      debtSmsResetAt: debtSmsResetAt ?? this.debtSmsResetAt,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
