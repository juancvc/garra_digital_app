import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/design/garra_colors.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';

void main() {
  test('design tokens preserve V3 crema identity', () {
    expect(GarraColors.cream, 0xFFF3E9D2);
    expect(GarraColors.gold, 0xFFC7A45B);
    expect(GarraColors.burgundy, 0xFF781C30);
    expect(GarraColors.background, 0xFF0E0C0B);
    expect(AppTheme.cream, const Color(GarraColors.cream));
    expect(AppTheme.burgundy, const Color(GarraColors.burgundy));
  });
}
