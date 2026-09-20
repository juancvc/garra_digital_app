import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/design/garra_colors.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';

void main() {
  test('design tokens preserve crema identity', () {
    expect(GarraColors.cream, 0xFFFFF1C7);
    expect(GarraColors.gold, 0xFFD6A84F);
    expect(GarraColors.garnet, 0xFF7A121C);
    expect(AppTheme.cream, const Color(GarraColors.cream));
  });
}
