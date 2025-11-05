import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final _auth = FirebaseAuth.instance;

  // Define aquí los correos autorizados en una lista
  static const List<String> _authorizedEmails = [
    "silvino.carlino@gmail.com",
    "4542058matt@gmail.com",
    "gruposcoutlasalle@gmail.com",
  ];

  static User? get user => _auth.currentUser;

  static Stream<User?> get userStream => _auth.userChanges();
  static bool get isEmailVerified => user?.emailVerified ?? false;

  // Método para verificar si el correo está autorizado
  static bool isAuthorizedEmail(String? email) {
    if (email == null) return false;

    // Convertir a minúsculas para comparación case-insensitive
    final emailLower = email.toLowerCase();

    return _authorizedEmails.any(
            (authorizedEmail) => authorizedEmail.toLowerCase() == emailLower
    );
  }

  static Future<UserCredential> signInWithGoogle() async {
    try {
      // Cerrar cualquier sesión previa
      await GoogleSignIn().signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        throw const NoGoogleAccountChosenException();
      }

      // Verificar si el correo está autorizado antes de continuar
      if (!isAuthorizedEmail(googleUser.email)) {
        await GoogleSignIn().signOut();
        throw const UnauthorizedEmailException();
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } on PlatformException catch (e) {
      print('PlatformException: ${e.code} - ${e.message}');
      await GoogleSignIn().signOut();

      if (e.code == 'sign_in_failed') {
        throw Exception('Error de configuración de Google Sign-In. Verifica SHA-1 en Firebase Console.');
      }
      rethrow;
    } catch (e) {
      print('Error general: $e');
      await GoogleSignIn().signOut();
      rethrow;
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}

// Excepciones personalizadas
class NoGoogleAccountChosenException implements Exception {
  const NoGoogleAccountChosenException();

  @override
  String toString() => 'No se seleccionó ninguna cuenta de Google';
}

class UnauthorizedEmailException implements Exception {
  const UnauthorizedEmailException();

  @override
  String toString() => 'Correo electrónico no autorizado para acceder al sistema';
}