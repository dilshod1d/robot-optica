import 'package:cloud_firestore/cloud_firestore.dart';

enum VisitStatus {
  pending,
  visited,
  lateVisited,
  notVisited,
}

class VisitModel {
  final String id;
  final String customerId;
  final String customerName;
  final String reason;
  final String? note;
  final DateTime visitDate;
  final DateTime? visitedDate;
  final VisitStatus status;
  final int remindersSent;
  final DateTime? smsResetAt;

  /// Needed for pagination
  final DocumentSnapshot? firestoreDoc;

  VisitModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.reason,
    this.note,
    required this.visitDate,
    this.visitedDate,
    this.status = VisitStatus.pending,
    this.remindersSent = 0,
    this.smsResetAt,
    this.firestoreDoc,
  });

  /// ✅ CREATE FACTORY
  factory VisitModel.create({
    required String customerId,
    required String customerName,
    required String reason,
    String? note,
    required DateTime visitDate,
  }) {
    final id = FirebaseFirestore.instance
        .collection('tmp')
        .doc()
        .id;

    return VisitModel(
      id: id,
      customerId: customerId,
      customerName: customerName,
      reason: reason,
      note: note,
      visitDate: visitDate,
      status: VisitStatus.pending,
      remindersSent: 0,
      smsResetAt: null,
    );
  }

  factory VisitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return VisitModel(
      id: doc.id,
      customerId: data['customerId'],
      customerName: data['customerName'],
      reason: data['reason'],
      note: data['note'],
      visitDate: (data['visitDate'] as Timestamp).toDate(),
      visitedDate: data['visitedDate'] != null
          ? (data['visitedDate'] as Timestamp).toDate()
          : null,
      status: _statusFromString(data['status']),
      remindersSent: data['remindersSent'] ?? 0,
      smsResetAt: data['smsResetAt'] != null
          ? (data['smsResetAt'] as Timestamp).toDate()
          : null,
      firestoreDoc: doc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'reason': reason,
      'note': note,
      'visitDate': Timestamp.fromDate(visitDate),
      'visitedDate':
      visitedDate != null ? Timestamp.fromDate(visitedDate!) : null,
      'status': status.name,
      'remindersSent': remindersSent,
      'smsResetAt': smsResetAt != null ? Timestamp.fromDate(smsResetAt!) : null,
    };
  }

  // ================= HELPERS =================

  bool get isPending => status == VisitStatus.pending;
  bool get isVisited => status == VisitStatus.visited;
  bool get isLate => status == VisitStatus.lateVisited;
  bool get isNotVisited => status == VisitStatus.notVisited;
  bool get isCompleted =>
      status == VisitStatus.visited || status == VisitStatus.lateVisited;

  static VisitStatus _statusFromString(String? status) {
    switch (status) {
      case 'visited':
        return VisitStatus.visited;
      case 'lateVisited':
        return VisitStatus.lateVisited;
      case 'notVisited':
        return VisitStatus.notVisited;
      case 'pending':
      default:
        return VisitStatus.pending;
    }
  }

  VisitModel copyWith({
    String? id,
    String? customerId,
    String? reason,
    String? note,
    DateTime? visitDate,
    DateTime? visitedDate,
    VisitStatus? status,
    int? remindersSent,
    DateTime? smsResetAt,
    DocumentSnapshot? firestoreDoc,
  }) {
    return VisitModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName,
      reason: reason ?? this.reason,
      note: note ?? this.note,
      visitDate: visitDate ?? this.visitDate,
      visitedDate: visitedDate ?? this.visitedDate,
      status: status ?? this.status,
      remindersSent: remindersSent ?? this.remindersSent,
      smsResetAt: smsResetAt ?? this.smsResetAt,
      firestoreDoc: firestoreDoc ?? this.firestoreDoc,
    );
  }
}
