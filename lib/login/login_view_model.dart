import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/local_storage_service.dart';

class LoginViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String? get userName => _auth.currentUser?.displayName;
  String? get userEmail => _auth.currentUser?.email;
  String? get userPhotoUrl => _auth.currentUser?.photoURL;

  Future<void> checkLoginStatus() async {
    _isLoggedIn = await LocalStorageService.isLoggedIn();
    if (_isLoggedIn) {
      print('LoginViewModel: Checked Status - User Logged In');
      print('LoginViewModel: Name: $userName');
      print('LoginViewModel: Email: $userEmail');
      print('LoginViewModel: PhotoURL: $userPhotoUrl');
    }
    notifyListeners();
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('LoginViewModel: Starting Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('LoginViewModel: Google Sign-In cancelled by user.');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      print('LoginViewModel: User selected: ${googleUser.email}');
      print('LoginViewModel: Display Name: ${googleUser.displayName}');
      print('LoginViewModel: ID: ${googleUser.id}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('LoginViewModel: Got tokens. AccessToken: ${googleAuth.accessToken != null ? "YES" : "NO"}, IdToken: ${googleAuth.idToken != null ? "YES" : "NO"}');

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('LoginViewModel: Signing into Firebase...');
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        final user = userCredential.user!;
        print('LoginViewModel: Firebase Login Success!');
        print('LoginViewModel: Firebase User Email: ${user.email}');
        print('LoginViewModel: Firebase UID: ${user.uid}');
        print('LoginViewModel: Name: $userName');
        print('LoginViewModel: PhotoURL: $userPhotoUrl');
        
        _isLoading = false;
        _isLoggedIn = true;
        await LocalStorageService.setLoggedIn(true);
        notifyListeners();
        return true;
      }
      
      print('LoginViewModel: Firebase user is null after sign in.');
      _isLoading = false;
      _errorMessage = "Google sign in failed";
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      print('LoginViewModel: EXCEPTION during Google Sign-In: $e');
      print('LoginViewModel: StackTrace: $stackTrace');
      _isLoading = false;
      _errorMessage = "Error: $e";
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        print('LoginViewModel: Email Login Success!');
        print('LoginViewModel: Name: $userName');
        print('LoginViewModel: Email: $userEmail');
        print('LoginViewModel: PhotoURL: $userPhotoUrl');
        _isLoading = false;
        _isLoggedIn = true;
        await LocalStorageService.setLoggedIn(true);
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "An unexpected error occurred";
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _isLoggedIn = false;
    await LocalStorageService.setLoggedIn(false);
    notifyListeners();
  }

  Future<bool> updateProfile({String? displayName, String? photoURL}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user != null) {
        if (displayName != null) await user.updateDisplayName(displayName);
        if (photoURL != null) await user.updatePhotoURL(photoURL);
        await user.reload();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = "No user logged in";
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithFacebook() async {
    _isLoading = true;
    notifyListeners();
    // Simulate FB login (Requires facebook_auth package)
    await Future.delayed(const Duration(seconds: 1));
    _isLoading = false;
    _isLoggedIn = true;
    await LocalStorageService.setLoggedIn(true);
    notifyListeners();
    return true;
  }

  Future<bool> loginWithPhone(String phoneNumber) async {
    _isLoading = true;
    notifyListeners();
    // Simulate Phone login
    await Future.delayed(const Duration(seconds: 1));
    _isLoading = false;
    _isLoggedIn = true;
    await LocalStorageService.setLoggedIn(true);
    notifyListeners();
    return true;
  }
}
