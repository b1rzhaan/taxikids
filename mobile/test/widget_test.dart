import 'package:flutter_test/flutter_test.dart';
import 'package:kidstransfer/core/theme.dart';

void main() {
  test('theme builds with brand color', () {
    final theme = buildTheme();
    expect(theme.colorScheme.primary, AppColors.brand);
  });
}
