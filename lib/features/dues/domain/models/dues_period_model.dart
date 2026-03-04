class DuesPeriodModel {
  const DuesPeriodModel({
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
  final DateTime dueDate;
  final DateTime createdAt;
}
