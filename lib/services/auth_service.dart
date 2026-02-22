import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Convert Firebase User → AppUser (from Firestore)
  Future<AppUser?> _userFromFirebase(User? user) async {
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      // First time login safety fallback
      final newUser = AppUser(
        uid: user.uid,
        email: user.email ?? '',
        role: 'owner',
        activeOpticaId: null,
      );

      await _db.collection('users').doc(user.uid).set(newUser.toMap());
      return newUser;
    }

    return AppUser.fromMap(user.uid, doc.data()!);
  }

  /// Auth state stream
  Stream<AppUser?> get user async* {
    await for (final firebaseUser in _auth.authStateChanges()) {
      yield await _userFromFirebase(firebaseUser);
    }
  }

  /// Sign up
  Future<AppUser?> signUp(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    return await _userFromFirebase(result.user);
  }

  /// Sign in
  Future<AppUser?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return await _userFromFirebase(result.user);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}


