import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthService {
  GoogleAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Future<String?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();

      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();

      debugPrint('GOOGLE STEP 1: initialized');

      final googleUser = await _googleSignIn.authenticate();

      debugPrint('GOOGLE STEP 2: authenticated user=${googleUser.email}');

      final googleAuth = googleUser.authentication;

      debugPrint('GOOGLE STEP 3: google idToken exists=${googleAuth.idToken != null}');

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final result = await _firebaseAuth.signInWithCredential(credential);

      debugPrint('GOOGLE STEP 4: firebase user=${result.user?.email}');

      final idToken = await result.user!.getIdToken();

      debugPrint('🔥 FIREBASE TOKEN: $idToken');

      return idToken;
    } catch (e, stack) {
      debugPrint('❌ ERROR EN GoogleAuthService: $e');
      debugPrint('❌ STACK GoogleAuthService: $stack');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.initialize();

    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      await _googleSignIn.signOut();
    }

    await _firebaseAuth.signOut();
  }
}