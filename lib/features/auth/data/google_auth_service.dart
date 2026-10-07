import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_sign_in_outcome.dart';

class GoogleAuthService {
  GoogleAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Future<GoogleSignInOutcome> signInWithGoogle() async {
    await _googleSignIn.initialize();

    try {
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final result = await _firebaseAuth.signInWithCredential(credential);
      final token = await result.user?.getIdToken();
      if (token == null || token.isEmpty) {
        return const GoogleSignInOutcome.failure(
          'No pudimos iniciar sesión con Google. Intenta de nuevo.',
        );
      }
      return GoogleSignInOutcome.success(token);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const GoogleSignInOutcome.cancelled();
      }
      return GoogleSignInOutcome.failure(_friendlyGoogleSignInMessage(e));
    } catch (_) {
      return const GoogleSignInOutcome.failure(
        'No pudimos iniciar sesión con Google. Intenta de nuevo.',
      );
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

String _friendlyGoogleSignInMessage(GoogleSignInException e) {
  switch (e.code) {
    case GoogleSignInExceptionCode.canceled:
      return '';
    case GoogleSignInExceptionCode.uiUnavailable:
      return 'No se pudo abrir Google. Intenta de nuevo.';
    case GoogleSignInExceptionCode.clientConfigurationError:
    case GoogleSignInExceptionCode.providerConfigurationError:
      return 'Google no está disponible en este momento.';
    case GoogleSignInExceptionCode.interrupted:
      return 'Inicio con Google interrumpido. Intenta de nuevo.';
    case GoogleSignInExceptionCode.userMismatch:
      return 'Elige la misma cuenta de Google e intenta de nuevo.';
    case GoogleSignInExceptionCode.unknownError:
      return 'No pudimos iniciar sesión con Google. Intenta de nuevo.';
  }
}
