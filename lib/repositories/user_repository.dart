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
  Future<void> setLanguageCode(String code);
  Future<void> sendEmailVerification();
  Future<void> verifyBeforeUpdateEmail(String newEmail);
  Future<bool> isEmailInUse(String email);
  Future<void> signOut();
  Stream<List<Map<String, dynamic>>> getUserVehicles(String uid);
  Future<void> addVehicle(String uid, Map<String, dynamic> data);
  Future<void> updateVehicle(
      String uid, String vehicleId, Map<String, dynamic> data);
  Future<void> deleteVehicle(String uid, String vehicleId);
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
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'no-current-user', message: 'User not logged in.');
    }
    await user.reload();
  }

  @override
  Future<void> setLanguageCode(String code) async {
    await _auth.setLanguageCode(code);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'no-current-user', message: 'User not logged in.');
    }
    await user.sendEmailVerification();
  }

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'no-current-user', message: 'User not logged in.');
    }
    await user.verifyBeforeUpdateEmail(newEmail);
  }

  @override
  Future<bool> isEmailInUse(String email) async {
    try {
      // 1. Check Firestore Users collection (Match original working logic)
      final q = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return true;

      // 2. Check Firebase Auth
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Stream<List<Map<String, dynamic>>> getUserVehicles(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  @override
  Future<void> addVehicle(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .add(data);
    await updateUserData(uid, data);
  }

  @override
  Future<void> updateVehicle(
      String uid, String vehicleId, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .doc(vehicleId)
        .update(data);
    await updateUserData(uid, data);
  }

  @override
  Future<void> deleteVehicle(String uid, String vehicleId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .doc(vehicleId)
        .delete();
  }
}
