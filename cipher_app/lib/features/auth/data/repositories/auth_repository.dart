import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../../../../core/constants/app_constants.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> sendOtp(String email) async {
    // Firebase Email Link (OTP style)
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: 'https://cipherapp.page.link/verify',
        handleCodeInApp: true,
        androidPackageName: 'com.example.cipher',
        androidInstallApp: true,
      ),
    );
  }

  Future<UserCredential> signInWithEmailLink(String email, String link) async {
    return await _auth.signInWithEmailLink(email: email, emailLink: link);
  }

  Future<UserModel> getOrCreateUser(User firebaseUser) async {
    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(firebaseUser.uid)
        .get();
    if (doc.exists) return UserModel.fromFirestore(doc);
    final newUser = UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.email?.split('@').first ?? 'User',
      createdAt: DateTime.now(),
    );
    await _db
        .collection(AppConstants.usersCollection)
        .doc(firebaseUser.uid)
        .set(newUser.toFirestore());
    return newUser;
  }

  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> updateUser(UserModel user) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.id)
        .update(user.toFirestore());
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection(AppConstants.usersCollection).doc(user.uid).delete();
    await user.delete();
  }

  Future<void> signOut() async => await _auth.signOut();
}
