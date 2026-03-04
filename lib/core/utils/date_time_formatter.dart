class DateTimeFormatter {
  static String date(DateTime value) {
    return '${_two(value.day)}.${_two(value.month)}.${value.year}';
  }

  static String dateTime(DateTime value) {
    return '${date(value)} ${_two(value.hour)}:${_two(value.minute)}';
  }

  static String _two(int value) {
    return value.toString().padLeft(2, '0');
  }
}
