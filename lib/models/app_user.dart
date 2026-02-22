class AppUser {
  final String uid;
  final String email;
  final String role;
  final String? activeOpticaId;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.activeOpticaId,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'],
      role: data['role'] ?? 'owner',
      activeOpticaId: data['activeOpticaId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'activeOpticaId': activeOpticaId,
    };
  }
}
