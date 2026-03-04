import 'package:hkd/core/session/session_storage.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/repositories/auth_repository.dart';

class SessionController {
  SessionController({
    required this.storage,
    required this.authRepository,
  });

  final SessionStorage storage;
  final AuthRepository authRepository;

  UserModel? _currentUser;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;

  bool get isInitialized => _isInitialized;

  bool get isLoggedIn => _currentUser != null;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _currentUser = await authRepository.restoreSession();

    if (_currentUser == null) {
      final String? userId = await storage.readUserId();
      if (userId != null) {
        _currentUser = await authRepository.fetchById(userId);
      }
    }

    if (_currentUser != null) {
      await storage.writeUserId(_currentUser!.id);
    }

    _isInitialized = true;
  }

  Future<void> login(UserModel user) async {
    _currentUser = user;
    await storage.writeUserId(user.id);
  }

  Future<void> logout() async {
    _currentUser = null;
    await authRepository.logout();
    await storage.clear();
  }
}
