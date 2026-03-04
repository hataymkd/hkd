import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/navigation/invite_deep_link_parser.dart';

class AppDeepLinkService {
  AppDeepLinkService._();

  static final AppDeepLinkService instance = AppDeepLinkService._();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingInviteToken;
  String? _lastHandledToken;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      final Uri? initial = await _appLinks.getInitialLink();
      _handleUri(initial, fromStream: false);
    } catch (_) {}

    _subscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleUri(uri, fromStream: true);
      },
      onError: (_) {},
    );
  }

  void attachNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  void detachNavigatorKey() {
    _navigatorKey = null;
  }

  String? consumePendingInviteToken() {
    final String? token = _pendingInviteToken;
    _pendingInviteToken = null;
    if (_lastHandledToken == token) {
      _lastHandledToken = null;
    }
    return token;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _pendingInviteToken = null;
    _lastHandledToken = null;
    _initialized = false;
    _navigatorKey = null;
  }

  void _handleUri(Uri? uri, {required bool fromStream}) {
    final String? token = _extractInviteToken(uri);
    if (token == null) {
      return;
    }

    if (_lastHandledToken == token) {
      return;
    }
    _lastHandledToken = token;
    _pendingInviteToken = token;

    if (fromStream) {
      _openInviteRoute(token);
    }
  }

  String? _extractInviteToken(Uri? uri) {
    return extractInviteTokenFromUri(uri);
  }

  void _openInviteRoute(String token) {
    final NavigatorState? navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      return;
    }

    navigator.pushNamed(
      AppRoutes.acceptInvite,
      arguments: token,
    );
  }
}
