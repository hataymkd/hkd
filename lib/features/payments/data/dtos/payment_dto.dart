import 'package:hkd/features/payments/domain/models/payment_model.dart';

class PaymentDto {
  const PaymentDto({
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
  final String status;
  final String dueDate;
  final String? paidAt;

  factory PaymentDto.fromMap(Map<String, dynamic> map) {
    return PaymentDto(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      period: map['period'] as String,
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] as String,
      dueDate: map['due_date'] as String,
      paidAt: map['paid_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'period': period,
      'amount': amount,
      'status': status,
      'due_date': dueDate,
      'paid_at': paidAt,
    };
  }
}

extension PaymentDtoMapper on PaymentDto {
  PaymentModel toDomain() {
    return PaymentModel(
      id: id,
      userId: userId,
      period: period,
      amount: amount,
      status: _statusFrom(status),
      dueDate: DateTime.parse(dueDate),
      paidAt: paidAt == null ? null : DateTime.parse(paidAt!),
    );
  }

  PaymentStatus _statusFrom(String raw) {
    switch (raw) {
      case 'paid':
        return PaymentStatus.paid;
      case 'pending':
        return PaymentStatus.pending;
      default:
        return PaymentStatus.overdue;
    }
  }
}

extension PaymentModelMapper on PaymentModel {
  PaymentDto toDto() {
    return PaymentDto(
      id: id,
      userId: userId,
      period: period,
      amount: amount,
      status: status.name,
      dueDate: dueDate.toIso8601String(),
      paidAt: paidAt?.toIso8601String(),
    );
  }
}
