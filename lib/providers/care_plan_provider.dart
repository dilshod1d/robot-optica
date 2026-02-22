import 'package:flutter/material.dart';
import '../models/care_plan_model.dart';
import '../services/care_plan_service.dart';

class CarePlanProvider with ChangeNotifier {
  final String opticaId;
  final String visitId;

  final CarePlanService _service = CarePlanService();

  CarePlanModel? _carePlan;
  bool _isLoading = false;

  CarePlanProvider({
    required this.opticaId,
    required this.visitId,
  });

  CarePlanModel? get carePlan => _carePlan;
  bool get isLoading => _isLoading;

  /// Load latest care plan
  Future<void> loadCarePlan() async {
    _isLoading = true;
    notifyListeners();

    try {
      _carePlan =
      await _service.fetchLatestCarePlan(opticaId, visitId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create new care plan
  Future<void> createCarePlan(CarePlanModel model) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.addCarePlan(opticaId, visitId, model);
      _carePlan = model;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Optional: update plan
  Future<void> updateCarePlan(CarePlanModel model) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.updateCarePlan(opticaId, visitId, model);
      _carePlan = model;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _carePlan = null;
    notifyListeners();
  }
}
