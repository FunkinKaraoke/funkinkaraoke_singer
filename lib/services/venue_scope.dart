// lib/services/venue_scope.dart
import 'package:flutter/material.dart';

class VenueSession extends ChangeNotifier {
  String? _code;
  String? get code => _code;

  void set(String? newCode) {
    _code = newCode;
    notifyListeners();
  }
}

class VenueScope extends InheritedNotifier<VenueSession> {
  const VenueScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static VenueSession of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<VenueScope>();
    assert(scope != null, 'VenueScope not found in context');
    return scope!.notifier!;
  }
}