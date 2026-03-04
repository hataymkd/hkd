import 'package:hkd/features/dues/domain/models/dues_invoice_model.dart';

class DuesInvoiceDto {
  const DuesInvoiceDto({
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
  final String status;
  final String dueDate;
  final String createdAt;
  final String? paidAt;

  factory DuesInvoiceDto.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> periodMap =
        (map['dues_periods'] as Map).cast<String, dynamic>();
    return DuesInvoiceDto(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      periodId: map['period_id'] as String,
      periodKey: periodMap['period_key'] as String,
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] as String,
      dueDate: periodMap['due_date'] as String,
      createdAt: map['created_at'] as String,
      paidAt: map['paid_at'] as String?,
    );
  }
}

extension DuesInvoiceDtoMapper on DuesInvoiceDto {
  DuesInvoiceModel toDomain() {
    final DateTime parsedDueDate = DateTime.parse(dueDate);

    return DuesInvoiceModel(
      id: id,
      userId: userId,
      periodId: periodId,
      periodKey: periodKey,
      amount: amount,
      status: _statusFrom(status, parsedDueDate),
      dueDate: parsedDueDate,
      createdAt: DateTime.parse(createdAt),
      paidAt: paidAt == null ? null : DateTime.parse(paidAt!),
    );
  }

  DuesInvoiceStatus _statusFrom(String raw, DateTime dueDateValue) {
    switch (raw) {
      case 'paid':
        return DuesInvoiceStatus.paid;
      case 'overdue':
        return DuesInvoiceStatus.overdue;
      default:
        final DateTime now = DateTime.now();
        final DateTime today = DateTime(now.year, now.month, now.day);
        final DateTime dueDateOnly = DateTime(
          dueDateValue.year,
          dueDateValue.month,
          dueDateValue.day,
        );
        if (dueDateOnly.isBefore(today)) {
          return DuesInvoiceStatus.overdue;
        }
        return DuesInvoiceStatus.unpaid;
    }
  }
}
