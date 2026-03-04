enum DuesInvoiceStatus {
  unpaid,
  paid,
  overdue,
}

extension DuesInvoiceStatusX on DuesInvoiceStatus {
  String get label {
    switch (this) {
      case DuesInvoiceStatus.unpaid:
        return 'Odenmedi';
      case DuesInvoiceStatus.paid:
        return 'Odendi';
      case DuesInvoiceStatus.overdue:
        return 'Gecikmis';
    }
  }
}

class DuesInvoiceModel {
  const DuesInvoiceModel({
    required this.id,
    required this.userId,
    required this.periodId,
    required this.periodKey,
    required this.amount,
    required this.status,
    required this.dueDate,
    required this.createdAt,
    this.paidAt,
  });

  final String id;
  final String userId;
  final String periodId;
  final String periodKey;
  final double amount;
  final DuesInvoiceStatus status;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime? paidAt;
}
