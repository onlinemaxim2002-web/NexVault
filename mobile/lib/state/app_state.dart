import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../models.dart';
import '../services/backend.dart';
import '../services/payments.dart';

/// App-wide state: the session (guest or logged in), install attribution,
/// consent, and the user's status (premium, source, storage).
class AppState extends ChangeNotifier {
  AppState._();
  static final instance = AppState._();

  late SharedPreferences _prefs;
  StreamSubscription<AuthState>? _authSub;

  bool ready = false;
  String? startupError;
  UserStatus? status;
  late String installId;

  /// Bumped whenever what the user may see changes (login, logout, source
  /// recorded, plan granted). Screens reload their data when it changes.
  final contentVersion = ValueNotifier<int>(0);

  /// Selected bottom tab: 0 Cloud, 1 Feed, 2 Explore, 3 Channels, 4 Profile.
  final tab = ValueNotifier<int>(2);

  bool get isGuest => status?.isGuest ?? true;
  bool get isPremium => status?.isPremium ?? false;
  bool get hasAdsAccess => status?.hasAdsAccess ?? false;
  bool get consentGiven => _prefs.getString('consent') == Config.policyVersion;
  String? get email => sb.auth.currentUser?.email;
  String? get userId => sb.auth.currentUser?.id;

  Future<void> start() async {
    startupError = null;
    notifyListeners();
    try {
      _prefs = await SharedPreferences.getInstance();
      installId = _prefs.getString('install_id') ?? const Uuid().v4();
      await _prefs.setString('install_id', installId);

      // Everyone starts as a guest: create an anonymous account once.
      if (sb.auth.currentSession == null) {
        await sb.auth.signInAnonymously();
      }
      await _recordInstall();
      await refreshStatus();
      Backend.logEvent(installId, 'app_open');

      _authSub ??= sb.auth.onAuthStateChange.listen((s) async {
        if (s.event == AuthChangeEvent.signedIn ||
            s.event == AuthChangeEvent.userUpdated) {
          await refreshStatus();
          bumpContent();
        }
      });
      ready = true;
      // Saved UPI answers (also from before a crash/kill) are sent now.
      payments.start();
    } catch (e) {
      startupError = friendlyError(e);
    }
    notifyListeners();
  }

  /// Ads APK carries APK_REFERRER; the plain APK has none ("direct").
  Future<void> _recordInstall() async {
    if (_prefs.getBool('install_recorded') == true) return;
    final hasReferrer = Config.apkReferrer.isNotEmpty;
    final source = await Backend.recordInstall(
      installId,
      hasReferrer ? 'apk' : 'not_available',
      hasReferrer ? Config.apkReferrer : null,
    );
    await _prefs.setBool('install_recorded', true);
    await _prefs.setString('install_source', source ?? 'unknown');
  }

  Future<void> refreshStatus() async {
    try {
      final s = await Backend.status();
      final changed =
          s?.isPremium != status?.isPremium ||
          s?.source != status?.source ||
          s?.isGuest != status?.isGuest;
      status = s;
      notifyListeners();
      if (changed && ready) bumpContent();
    } catch (_) {
      // Keep the last known status when offline.
    }
  }

  void bumpContent() => contentVersion.value++;

  Future<void> acceptConsent() async {
    await _prefs.setString('consent', Config.policyVersion);
    notifyListeners();
    try {
      await Backend.saveConsent(Config.policyVersion);
    } catch (_) {}
  }

  /// Guest → full account with the same user id (keeps everything).
  /// Returns false when the email must be confirmed first.
  Future<bool> createAccount(String email, String password) async {
    final res = await sb.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
    await refreshStatus();
    bumpContent();
    return res.user?.email == email;
  }

  Future<void> logIn(String email, String password) async {
    await sb.auth.signInWithPassword(email: email, password: password);
    try {
      await Backend.attributeUser(installId);
    } catch (_) {}
    Backend.logEvent(installId, 'login');
    await refreshStatus();
    bumpContent();
  }

  /// Logging out (or deleting the account) starts a fresh guest session.
  Future<void> logOut() async {
    await sb.auth.signOut();
    await sb.auth.signInAnonymously();
    try {
      await Backend.attributeUser(installId);
    } catch (_) {}
    await refreshStatus();
    bumpContent();
  }

  Future<void> updateName(String name) async {
    await Backend.updateName(name);
    await refreshStatus();
  }

  Future<void> deleteAccount() async {
    await Backend.deleteAccount();
    await logOut();
  }
}

AppState get app => AppState.instance;
