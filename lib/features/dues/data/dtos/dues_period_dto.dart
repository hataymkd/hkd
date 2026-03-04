import 'package:hkd/features/dues/domain/models/dues_period_model.dart';

class DuesPeriodDto {
  const DuesPeriodDto({
    required this.id,
    required this.year,
    required this.month,
    required this.periodKey,
    required this.amount,
    required this.dueDate,
    required this.createdAt,
  });

  final String id;
  final int year;
  final int month;
  final String periodKey;
  final double amount;
  final String dueDate;
  final String createdAt;

  factory DuesPeriodDto.fromMap(Map<String, dynamic> map) {
    return DuesPeriodDto(
      id: map['id'] as String,
      year: (map['year'] as num).toInt(),
      month: (map['month'] as num).toInt(),
      periodKey: map['period_key'] as String,
      amount: (map['amount'] as num).toDouble(),
      dueDate: map['due_date'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}

extension DuesPeriodDtoMapper on DuesPeriodDto {
  DuesPeriodModel toDomain() {
    return DuesPeriodModel(
      id: id,
      year: year,
      month: month,
      periodKey: periodKey,
      amount: amount,
      dueDate: DateTime.parse(dueDate),
      createdAt: DateTime.parse(createdAt),
    );
  }
}
