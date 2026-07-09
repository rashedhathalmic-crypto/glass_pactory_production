import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'screen_type.dart';

abstract final class ResponsiveHelper {
  static ScreenType screenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppConstants.desktopBreakpoint) return ScreenType.desktop;
    if (width >= AppConstants.tabletBreakpoint) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  static bool isMobile(BuildContext context) =>
      screenType(context) == ScreenType.mobile;

  static bool isTablet(BuildContext context) =>
      screenType(context) == ScreenType.tablet;

  static bool isDesktop(BuildContext context) =>
      screenType(context) == ScreenType.desktop;

  static double contentMaxWidth(BuildContext context) {
    return switch (screenType(context)) {
      ScreenType.desktop => 1400,
      ScreenType.tablet => 960,
      ScreenType.mobile => double.infinity,
    };
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return switch (screenType(context)) {
      ScreenType.desktop => const EdgeInsets.all(32),
      ScreenType.tablet => const EdgeInsets.all(24),
      ScreenType.mobile => const EdgeInsets.all(16),
    };
  }

  static int gridColumns(BuildContext context) {
    return switch (screenType(context)) {
      ScreenType.desktop => 4,
      ScreenType.tablet => 2,
      ScreenType.mobile => 1,
    };
  }

  static int departmentGridColumns(BuildContext context) {
    return value(
      context: context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );
  }

  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    return switch (screenType(context)) {
      ScreenType.desktop => desktop ?? tablet ?? mobile,
      ScreenType.tablet => tablet ?? mobile,
      ScreenType.mobile => mobile,
    };
  }
}
