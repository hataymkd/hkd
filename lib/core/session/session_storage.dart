abstract class SessionStorage {
  Future<String?> readUserId();

  Future<void> writeUserId(String userId);

  Future<void> clear();
}
