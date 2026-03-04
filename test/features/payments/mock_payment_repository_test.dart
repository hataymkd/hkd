import 'package:flutter_test/flutter_test.dart';
import 'package:hkd/features/payments/data/mock_payment_repository.dart';
import 'package:hkd/features/payments/domain/models/payment_model.dart';

void main() {
  late MockPaymentRepository repository;

  setUp(() {
    repository = MockPaymentRepository();
  });

  test('fetch periods returns non-empty descending list', () {
    final periods = repository.fetchPeriods();

    expect(periods, isNotEmpty);
    expect(periods.first.compareTo(periods.last) >= 0, isTrue);
  });

  test('ensure user payment plan creates pending records for new user',
      () async {
    await repository.ensureUserPaymentPlan('new-user-1');

    final List<PaymentModel> records = repository.fetchPaymentsByUserId(
      'new-user-1',
    );
    expect(records, isNotEmpty);
    expect(
      records
          .every((PaymentModel item) => item.status == PaymentStatus.pending),
      isTrue,
    );
  });
}
