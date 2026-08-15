import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/features/navigation/navigation_screen.dart';

void main() {
  group('NudgedFabLocation', () {
    test('is a distinct location from centerDocked', () {
      const location = NudgedFabLocation();
      expect(location, isNot(equals(FloatingActionButtonLocation.centerDocked)));
      expect(location.toString(), 'NudgedFabLocation');
    });

    test('shifts the FAB left and up relative to centerDocked', () {
      expect(NudgedFabLocation.dx, lessThan(0), reason: 'should move left');
      expect(NudgedFabLocation.dy, lessThan(0), reason: 'should move up');
    });
  });
}
