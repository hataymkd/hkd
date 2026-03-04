import 'package:flutter_test/flutter_test.dart';
import 'package:hkd/core/session/session_controller.dart';
import 'package:hkd/core/session/session_storage.dart';
import 'package:hkd/features/auth/data/mock_auth_repository.dart';

class FakeSessionStorage implements SessionStorage {
  String? _cachedUserId;

  @override
  Future<void> clear() async {
    _cachedUserId = null;
  }

  @override
  Future<String?> readUserId() async {
    return _cachedUserId;
  }

  @override
  Future<void> writeUserId(String userId) async {
    _cachedUserId = userId;
  }
}

void main() {
  late MockAuthRepository authRepository;
  late FakeSessionStorage storage;
  late SessionController controller;

  setUp(() {
    authRepository = MockAuthRepository();
    storage = FakeSessionStorage();
    controller =
        SessionController(storage: storage, authRepository: authRepository);
  });

  test('initialize restores existing user session', () async {
    await storage.writeUserId('user-1');
    await controller.initialize();

    expect(controller.currentUser, isNotNull);
    expect(controller.currentUser!.id, 'user-1');
  });

  test('login and logout update persistent storage', () async {
    final user = await authRepository.login(
      phone: '05001112233',
      password: '123456',
    );
    expect(user, isNotNull);

    await controller.login(user!);
    expect(await storage.readUserId(), user.id);

    await controller.logout();
    expect(await storage.readUserId(), isNull);
  });
}
