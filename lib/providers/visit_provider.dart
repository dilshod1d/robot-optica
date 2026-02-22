import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/visit_model.dart';
import '../services/visit_service.dart';

class VisitProvider extends ChangeNotifier {
  final VisitService _service = VisitService();

  // ================= DATA =================

  List<VisitModel> _visits = [];
  bool _isLoading = false;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;

  List<VisitModel> get visits => _visits;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  List<VisitModel> _recentVisits = [];
  bool _isRecentLoading = false;
  List<VisitModel> get recentVisits => _recentVisits;
  bool get isRecentLoading => _isRecentLoading;

  // ================= STATS =================

  int pendingCount = 0;
  int visitedCount = 0;
  int lateCount = 0;
  int missedCount = 0;

  int todayCount = 0;
  int last7DaysCount = 0;
  int last30DaysCount = 0;
  int yearCount = 0;

  bool isStatsLoading = false;

  // ================= RESET =================

  void reset() {
    _visits = [];
    _lastDoc = null;
    _hasMore = true;
    notifyListeners();
  }

  // ================= FETCH =================

  Future<void> fetchAllVisits(
      String opticaId, {
        int limit = 20,
        bool loadMore = false,
      }) async {
    if (_isLoading) return;
    if (loadMore && !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _service.fetchAllVisits(
        opticaId: opticaId,
        startAfterDoc: loadMore ? _lastDoc : null,
        limit: limit,
      );

      if (!loadMore) {
        _visits = result;
      } else {
        _visits.addAll(result);
      }

      if (result.length < limit) {
        _hasMore = false;
      }

      if (result.isNotEmpty) {
        _lastDoc = result.last.firestoreDoc;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFilteredVisits(
      String opticaId,
      String filter, {
        int limit = 20,
        bool loadMore = false,
      }) async {
    if (_isLoading) return;
    if (loadMore && !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _service.fetchFilteredVisits(
        opticaId,
        filter,
        startAfterDoc: loadMore ? _lastDoc : null,
        limit: limit,
      );

      if (!loadMore) {
        _visits = result;
      } else {
        _visits.addAll(result);
      }

      if (result.length < limit) {
        _hasMore = false;
      }

      if (result.isNotEmpty) {
        _lastDoc = result.last.firestoreDoc;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchVisitsByCustomer(
      String opticaId,
      String customerId,
      ) async {
    _isLoading = true;
    notifyListeners();

    try {
      _visits = await _service.fetchVisitsByCustomer(
        opticaId,
        customerId,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= STATS =================

  Future<void> fetchVisitStats(String opticaId) async {
    if (isStatsLoading) return;

    isStatsLoading = true;
    notifyListeners();

    try {
      pendingCount = (await _service.getPendingVisits(opticaId))!;
      visitedCount = (await _service.getCompletedVisits(opticaId))!;
      lateCount = (await _service.getLateVisits(opticaId))!;
      missedCount = (await _service.getMissedVisits(opticaId))!;

      todayCount = (await _service.getVisitsToday(opticaId))!;
      last7DaysCount = (await _service.getVisitsLast7Days(opticaId))!;
      last30DaysCount = (await _service.getVisitsLast30Days(opticaId))!;
      yearCount = (await _service.getVisitsThisYear(opticaId))!;
    } finally {
      isStatsLoading = false;
      notifyListeners();
    }
  }

  // ================= MUTATIONS =================

  Future<String> addVisit(String opticaId, VisitModel visit) async {
    final visitId = await _service.addVisit(opticaId, visit);

    final visitWithId = visit.copyWith(id: visitId);

    _visits.insert(0, visitWithId);

    fetchVisitStats(opticaId);
    notifyListeners();

    return visitId;
  }




  Future<void> updateVisit(String opticaId, VisitModel visit) async {
    await _service.updateVisit(opticaId, visit);

    final index = _visits.indexWhere((v) => v.id == visit.id);
    if (index != -1) {
      _visits[index] = visit;
      notifyListeners();
    }

    fetchVisitStats(opticaId);
  }

  Future<void> rescheduleVisit({
    required String opticaId,
    required VisitModel visit,
    required DateTime newDate,
    required bool resetSms,
  }) async {
    await _service.rescheduleVisit(
      opticaId: opticaId,
      visit: visit,
      newDate: newDate,
      resetSms: resetSms,
    );

    final updated = visit.copyWith(
      visitDate: newDate,
      status: VisitStatus.pending,
      visitedDate: null,
      remindersSent: resetSms ? 0 : visit.remindersSent,
      smsResetAt: resetSms ? DateTime.now() : visit.smsResetAt,
    );

    final index = _visits.indexWhere((v) => v.id == visit.id);
    if (index != -1) {
      _visits[index] = updated;
    }

    final recentIndex = _recentVisits.indexWhere((v) => v.id == visit.id);
    if (recentIndex != -1) {
      _recentVisits[recentIndex] = updated;
    }

    notifyListeners();
    fetchVisitStats(opticaId);
  }

  Future<void> markVisited(String opticaId, VisitModel visit) async {
    await _service.markVisited(opticaId, visit);

    final now = DateTime.now();
    final newStatus = now.isAfter(visit.visitDate)
        ? VisitStatus.lateVisited
        : VisitStatus.visited;

    final index = _visits.indexWhere((v) => v.id == visit.id);
    if (index != -1) {
      _visits[index] = VisitModel(
        id: visit.id,
        customerId: visit.customerId,
        customerName: visit.customerName,
        reason: visit.reason,
        note: visit.note,
        visitDate: visit.visitDate,
        visitedDate: now,
        status: newStatus,
        remindersSent: visit.remindersSent,
      );
      notifyListeners();
    }

    fetchVisitStats(opticaId);
  }

  Future<void> markNotVisited(String opticaId, String visitId) async {
    await _service.markNotVisited(opticaId, visitId);

    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index != -1) {
      final visit = _visits[index];
      _visits[index] = VisitModel(
        id: visit.id,
        customerId: visit.customerId,
        customerName: visit.customerName,
        reason: visit.reason,
        note: visit.note,
        visitDate: visit.visitDate,
        visitedDate: null,
        status: VisitStatus.notVisited,
        remindersSent: visit.remindersSent,
      );
      notifyListeners();
    }

    fetchVisitStats(opticaId);
  }

  Future<void> deleteVisit(String opticaId, String visitId) async {
    await _service.deleteVisit(opticaId, visitId);
    _visits.removeWhere((v) => v.id == visitId);

    fetchVisitStats(opticaId);
    notifyListeners();
  }

  Future<void> fetchRecentVisits(String opticaId, {int limit = 5}) async {
    if (_isRecentLoading) return;

    _isRecentLoading = true;
    notifyListeners();

    try {
      _recentVisits = await _service.fetchRecentVisits(
        opticaId,
        limit: limit,
      );
    } finally {
      _isRecentLoading = false;
      notifyListeners();
    }
  }

}
