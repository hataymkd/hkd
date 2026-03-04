enum PaymentStatus {
  paid,
  pending,
  overdue,
}

extension PaymentStatusX on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Odendi';
      case PaymentStatus.pending:
        return 'Bekliyor';
      case PaymentStatus.overdue:
        return 'Gecikmis';
    }
  }
}

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.userId,
    required this.period,
    required this.amount,
    required this.status,
    required this.dueDate,
    this.paidAt,
  });

  final String id;
  final String userId;
  final String period;
  final double amount;
  final PaymentStatus status;
  final DateTime dueDate;
  final DateTime? paidAt;

  PaymentModel copyWith({
    String? id,
    String? userId,
    String? period,
    double? amount,
    PaymentStatus? status,
    DateTime? dueDate,
    DateTime? paidAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      period: period ?? this.period,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
