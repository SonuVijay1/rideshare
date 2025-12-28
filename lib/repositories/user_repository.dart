import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? phoneNumber;
  final bool emailVerified;
  AppUser(
      {required this.uid,
      this.email,
      this.phoneNumber,
      required this.emailVerified});
}

abstract class UserRepository {
  AppUser? get currentUser;
  Stream<Map<String, dynamic>?> getUserStream(String uid);
  Future<Map<String, dynamic>?> getUser(String uid);
  Future<void> updateUserData(String uid, Map<String, dynamic> data);
  Future<void> incrementUserStat(String uid, String field, int amount);
  Future<void> reloadUser();
  Future<void> sendEmailVerification();
  Future<void> verifyBeforeUpdateEmail(String newEmail);
  Future<bool> isEmailInUse(String email);
  Future<void> signOut();
}

class FirebaseUserRepository implements UserRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email,
      phoneNumber: user.phoneNumber,
      emailVerified: user.emailVerified,
    );
  }

  @override
  Stream<Map<String, dynamic>?> getUserStream(String uid) {
    return _firestore
        .collection("users")
        .doc(uid)
        .snapshots()
        .map((doc) => _convertTimestamps(doc.data()));
  }

  @override
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _firestore.collection("users").doc(uid).get();
    return _convertTimestamps(doc.data());
  }

  Map<String, dynamic>? _convertTimestamps(Map<String, dynamic>? data) {
    if (data == null) return null;
    // Create a copy to avoid mutating the original if needed,
    // though doc.data() is usually fresh.
    return data.map((key, value) {
      if (value is Timestamp) return MapEntry(key, value.toDate());
      return MapEntry(key, value);
    });
  }

  @override
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection("users")
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<void> incrementUserStat(String uid, String field, int amount) async {
    await _firestore.collection("users").doc(uid).update({
      field: FieldValue.increment(amount),
    });
  }

  @override
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  @override
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail) async {
    await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
  }

  @override
  Future<bool> isEmailInUse(String email) async {
    try {
      // 1. Check Firebase Auth
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) return true;

      // 2. Check Firestore Users collection (to prevent duplicates in DB)
      final q = await _firestore.collection('users').where('email', isEqualTo: email).limit(1).get();
      return q.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
