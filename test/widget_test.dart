import 'package:flutter_test/flutter_test.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';

void main() {
  test('DateTimeFormatter formats date and time', () {
    final dt = DateTime(2026, 2, 28, 9, 5);

    expect(DateTimeFormatter.date(dt), '28.02.2026');
    expect(DateTimeFormatter.dateTime(dt), '28.02.2026 09:05');
  });
}
