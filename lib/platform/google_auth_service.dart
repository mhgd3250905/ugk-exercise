import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthResult {
  const GoogleAuthResult({required this.idToken});

  final String idToken;
}

class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  var _initialized = false;

  Future<void> initialize({required String serverClientId}) async {
    if (_initialized) {
      return;
    }
    await _signIn.initialize(serverClientId: serverClientId);
    _initialized = true;
  }

  Future<GoogleAuthResult?> signIn() async {
    if (!_signIn.supportsAuthenticate()) {
      return null;
    }
    final account = await _signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      return null;
    }
    return GoogleAuthResult(idToken: idToken);
  }

  Future<void> signOut() async {
    await _signIn.signOut();
  }
}
