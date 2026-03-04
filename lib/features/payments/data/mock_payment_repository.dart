import 'package:hkd/features/payments/domain/models/payment_model.dart';
import 'package:hkd/features/payments/domain/repositories/payment_repository.dart';
import 'package:hkd/features/payments/domain/models/payment_summary_model.dart';

class MockPaymentRepository implements PaymentRepository {
  double _monthlyDueAmount = 750;
  int _nextPaymentId = 11;

  final List<PaymentModel> _payments = <PaymentModel>[
    PaymentModel(
      id: 'pay-1',
      userId: 'user-1',
      period: '2026-01',
      amount: 750,
      status: PaymentStatus.paid,
      dueDate: DateTime(2026, 1, 10),
      paidAt: DateTime(2026, 1, 6),
    ),
    PaymentModel(
      id: 'pay-2',
      userId: 'user-1',
      period: '2026-02',
      amount: 750,
      status: PaymentStatus.paid,
      dueDate: DateTime(2026, 2, 10),
      paidAt: DateTime(2026, 2, 8),
    ),
    PaymentModel(
      id: 'pay-3',
      userId: 'user-1',
      period: '2026-03',
      amount: 750,
      status: PaymentStatus.pending,
      dueDate: DateTime(2026, 3, 10),
    ),
    PaymentModel(
      id: 'pay-4',
      userId: 'user-2',
      period: '2026-01',
      amount: 750,
      status: PaymentStatus.paid,
      dueDate: DateTime(2026, 1, 10),
      paidAt: DateTime(2026, 1, 9),
    ),
    PaymentModel(
      id: 'pay-5',
      userId: 'user-2',
      period: '2026-02',
      amount: 750,
      status: PaymentStatus.pending,
      dueDate: DateTime(2026, 2, 10),
    ),
    PaymentModel(
      id: 'pay-6',
      userId: 'user-2',
      period: '2026-03',
      amount: 750,
      status: PaymentStatus.pending,
      dueDate: DateTime(2026, 3, 10),
    ),
    PaymentModel(
      id: 'pay-7',
      userId: 'user-2',
      period: '2025-12',
      amount: 750,
      status: PaymentStatus.overdue,
      dueDate: DateTime(2025, 12, 10),
    ),
    PaymentModel(
      id: 'pay-8',
      userId: 'user-3',
      period: '2025-12',
      amount: 750,
      status: PaymentStatus.overdue,
      dueDate: DateTime(2025, 12, 10),
    ),
    PaymentModel(
      id: 'pay-9',
      userId: 'user-3',
      period: '2026-01',
      amount: 750,
      status: PaymentStatus.overdue,
      dueDate: DateTime(2026, 1, 10),
    ),
    PaymentModel(
      id: 'pay-10',
      userId: 'user-3',
      period: '2026-02',
      amount: 750,
      status: PaymentStatus.pending,
      dueDate: DateTime(2026, 2, 10),
    ),
    PaymentModel(
      id: 'pay-11',
      userId: 'user-3',
      period: '2026-03',
      amount: 750,
      status: PaymentStatus.pending,
      dueDate: DateTime(2026, 3, 10),
    ),
  ];

  @override
  List<PaymentModel> fetchPayments() {
    return List<PaymentModel>.unmodifiable(_payments);
  }

  @override
  List<PaymentModel> fetchPaymentsByUserId(String userId) {
    final List<PaymentModel> list =
        _payments.where((PaymentModel item) => item.userId == userId).toList()
          ..sort(
            (PaymentModel first, PaymentModel second) =>
                second.dueDate.compareTo(first.dueDate),
          );
    return list;
  }

  @override
  List<String> fetchPeriods() {
    final Set<String> periods =
        _payments.map((PaymentModel item) => item.period).toSet();
    final List<String> list = periods.toList()
      ..sort((String a, String b) => b.compareTo(a));
    return list;
  }

  @override
  PaymentSummaryModel summaryFor(List<PaymentModel> payments) {
    final int paidCount = payments
        .where((PaymentModel item) => item.status == PaymentStatus.paid)
        .length;
    final int pendingCount = payments
        .where((PaymentModel item) => item.status == PaymentStatus.pending)
        .length;
    final int overdueCount = payments
        .where((PaymentModel item) => item.status == PaymentStatus.overdue)
        .length;
    final double totalAmount = payments.fold(
      0,
      (double previous, PaymentModel item) => previous + item.amount,
    );
    final double overdueAmount = payments
        .where((PaymentModel item) => item.status == PaymentStatus.overdue)
        .fold(
          0,
          (double previous, PaymentModel item) => previous + item.amount,
        );

    return PaymentSummaryModel(
      totalCount: payments.length,
      paidCount: paidCount,
      pendingCount: pendingCount,
      overdueCount: overdueCount,
      totalAmount: totalAmount,
      overdueAmount: overdueAmount,
    );
  }

  @override
  double get monthlyDueAmount => _monthlyDueAmount;

  @override
  Future<void> setMonthlyDueAmount(double amount) async {
    if (amount <= 0) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
    _monthlyDueAmount = amount;

    for (int i = 0; i < _payments.length; i++) {
      _payments[i] = _payments[i].copyWith(amount: amount);
    }
  }

  @override
  Future<void> ensureUserPaymentPlan(String userId) async {
    final bool alreadyExists = _payments.any(
      (PaymentModel item) => item.userId == userId,
    );
    if (alreadyExists) {
      return;
    }

    final List<String> periods = fetchPeriods();
    final List<String> seedPeriods = periods.isNotEmpty
        ? periods.take(3).toList()
        : <String>['2026-01', '2026-02', '2026-03'];

    for (final String period in seedPeriods) {
      final List<String> split = period.split('-');
      final int year = int.parse(split[0]);
      final int month = int.parse(split[1]);
      _nextPaymentId += 1;
      _payments.add(
        PaymentModel(
          id: 'pay-$_nextPaymentId',
          userId: userId,
          period: period,
          amount: _monthlyDueAmount,
          status: PaymentStatus.pending,
          dueDate: DateTime(year, month, 10),
        ),
      );
    }
  }
}
