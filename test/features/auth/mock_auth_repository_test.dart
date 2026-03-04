import 'package:flutter_test/flutter_test.dart';
import 'package:hkd/features/auth/data/mock_auth_repository.dart';
import 'package:hkd/features/membership/domain/models/membership_application_model.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  test('login succeeds for active user with valid credentials', () async {
    final user = await repository.login(
      phone: '05001112233',
      password: '123456',
    );

    expect(user, isNotNull);
    expect(user!.name, 'Ahmet Kaya');
  });

  test('submitting membership application creates pending record', () async {
    await repository.submitMembershipApplication(
      name: 'Yeni Uye',
      phone: '05007778899',
      password: '654321',
    );

    final application = repository.getLatestMembershipApplicationByPhone(
      '05007778899',
    );

    expect(application, isNotNull);
    expect(application!.status, MembershipApplicationStatus.pending);
  });

  test('approved application creates active member', () async {
    await repository.submitMembershipApplication(
      name: 'Aday Uye',
      phone: '05008889900',
      password: '654321',
    );
    final application = repository.getLatestMembershipApplicationByPhone(
      '05008889900',
    );
    expect(application, isNotNull);

    await repository.approveMembershipApplication(
      applicationId: application!.id,
      approvedBy: 'Ahmet Kaya',
    );

    final user = await repository.login(
      phone: '05008889900',
      password: '654321',
    );
    expect(user, isNotNull);
    expect(user!.isActive, isTrue);
  });

  test('otp flow succeeds for active user', () async {
    await repository.requestLoginOtp(phone: '05001112233');

    final user = await repository.verifyLoginOtp(
      phone: '05001112233',
      otpCode: '123456',
    );

    expect(user, isNotNull);
    expect(user!.name, 'Ahmet Kaya');
  });

  test('otp flow fails with invalid code', () async {
    await repository.requestLoginOtp(phone: '05001112233');

    final user = await repository.verifyLoginOtp(
      phone: '05001112233',
      otpCode: '000000',
    );

    expect(user, isNull);
  });
}
