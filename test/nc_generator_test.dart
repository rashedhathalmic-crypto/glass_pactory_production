import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/nc_generator.dart';

void main() {
  test('default browser output matches the native NC generator', () {
    final expected = File(
      'test/fixtures/129-122-03-211-default.nc',
    ).readAsStringSync();

    expect(
      NcGenerator.generate(
        const NcParameters(profile: '129-122-03-211'),
      ),
      expected,
    );
  });

  test('custom dimensions and corrections match the native NC generator', () {
    final expected = File(
      'test/fixtures/129-122-03-102-custom.nc',
    ).readAsStringSync();

    expect(
      NcGenerator.generate(
        const NcParameters(
          profile: '129-122-03-102',
          toolDiameter: 110.2,
          toolWidth: 26,
          thickness: 21,
          xCorrection: .8,
          yCorrection: -.3,
          roughingFeed: 900,
          finishingFeed: 1800,
          programNumber: 'O0420',
        ),
      ),
      expected,
    );
  });

  test('invalid machine parameters are rejected', () {
    expect(
      () => NcGenerator.generate(
        const NcParameters(profile: 'unknown'),
      ),
      throwsArgumentError,
    );
    expect(
      () => NcGenerator.generate(
        const NcParameters(
          profile: '129-122-03-210',
          workOffset: 'G92',
        ),
      ),
      throwsArgumentError,
    );
  });
}
