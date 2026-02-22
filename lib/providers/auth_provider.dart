import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/optica_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final OpticaService _opticaService = OpticaService();

  AppUser? _user;
  bool _isLoading = true;
  bool _needsOpticaCreation = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get needsOpticaCreation => _needsOpticaCreation;
  String? get opticaId => _user?.activeOpticaId;

  AuthProvider() {
    _authService.user.listen((user) async {
      _user = user;
      _needsOpticaCreation = false;

      if (user != null && user.activeOpticaId == null) {
        final optica = await _opticaService.getUserOptica(user.uid);

        if (optica == null) {
          _needsOpticaCreation = true;
        }
      }

      _isLoading = false;
      notifyListeners();
    });
  }


  Future<String?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = await _authService.signIn(email, password);

      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return 'Failed to sign in';
      }

      _user = user;
      _isLoading = false;
      notifyListeners();

      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }


  Future<String?> signUp(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signUp(email, password);

      // SignUp success, loading will be turned off when stream emits user
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut();

    // After sign out, loading will be turned off when stream emits null user
    // so no need to set _isLoading = false here
  }

  Future<void> createOptica({
    required String name,
    required String phone,
  }) async {
    if (_user == null) return;

    _isLoading = true;
    notifyListeners();

    // 1. Create optica + link to user
    await _opticaService.createOptica(
      name: name,
      ownerId: _user!.uid,
      phone: phone,
    );

    // 2. Refresh user FROM FIRESTORE (NOT AUTH)
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();

    _user = AppUser.fromMap(_user!.uid, doc.data()!);

    _needsOpticaCreation = false;
    _isLoading = false;
    notifyListeners();
  }


}
