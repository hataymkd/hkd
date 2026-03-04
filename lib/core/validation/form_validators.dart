class FormValidators {
  static String? requiredText(
    String? value, {
    required String fieldName,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName zorunludur.';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefon zorunludur.';
    }
    final String normalized = value.replaceAll(RegExp(r'[\s()-]+'), '');
    final bool isTurkishMobile = RegExp(r'^05\d{9}$').hasMatch(normalized) ||
        RegExp(r'^90\d{10}$').hasMatch(normalized) ||
        RegExp(r'^\+90\d{10}$').hasMatch(normalized);
    if (!isTurkishMobile) {
      return 'Telefon formati 05XXXXXXXXX veya +90XXXXXXXXXX olmali.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Sifre zorunludur.';
    }
    if (value.trim().length < 6) {
      return 'Sifre en az 6 karakter olmali.';
    }
    return null;
  }

  static String? otpCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'OTP kodu zorunludur.';
    }
    final String normalized = value.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{4,8}$').hasMatch(normalized)) {
      return 'OTP kodu 4-8 haneli olmali.';
    }
    return null;
  }

  static String? uuid(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Takip kodu zorunludur.';
    }
    final RegExp uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidRegex.hasMatch(value.trim())) {
      return 'Gecerli bir UUID giriniz.';
    }
    return null;
  }

  static String? inviteToken(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Davet tokeni zorunludur.';
    }
    final String normalized = value.trim();
    final RegExp tokenRegex = RegExp(r'^[A-Za-z0-9_-]{16,}$');
    if (!tokenRegex.hasMatch(normalized)) {
      return 'Gecerli bir davet tokeni giriniz.';
    }
    return null;
  }
}
