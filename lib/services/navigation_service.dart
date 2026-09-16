import 'package:flutter/material.dart';

/// Holds a global [NavigatorKey] so that the notification tap handler
/// can push routes without needing a [BuildContext].
class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState? get navigator => navigatorKey.currentState;

  /// Navigate to a named route from anywhere (including notification callbacks).
  static void navigateTo(String routeName, {Object? arguments}) {
    navigator?.pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }
}
