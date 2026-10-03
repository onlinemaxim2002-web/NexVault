import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';
import 'backend.dart';

/// Thrown when no UPI app (GPay, PhonePe, Paytm, BHIM…) is installed.
class NoUpiAppException implements Exception {
  @override
  String toString() =>
      'No UPI app found. Install Google Pay, PhonePe, Paytm or BHIM to pay.';
}

/// The order being paid, kept on the phone so it can be recovered after a
/// restart (for 24 hours, like the server).
class OpenOrder {
  final String id;
  final String reference;
  final String amount; // "129.00"
  final String planName;
  final DateTime createdAt;

  const OpenOrder({
    required this.id,
    required this.reference,
    required this.amount,
    required this.planName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'amount': amount,
    'plan_name': planName,
    'created_at': createdAt.toIso8601String(),
  };

  factory OpenOrder.fromJson(Map<String, dynamic> j) => OpenOrder(
    id: j['id'] as String,
    reference: j['reference'] as String,
    amount: j['amount'] as String,
    planName: j['plan_name'] as String? ?? '',
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

/// UPI Intent payments, app side.
///
/// 1. [pay] asks the server for an order (amount decided by the server), saves
///    it, and opens the UPI app through a chooser.
/// 2. MainActivity.kt saves the UPI app's raw answer the moment it arrives, even
///    if Android killed the app meanwhile.
/// 3. [flush] (started with the app, on resume and when an answer arrives)
///    refreshes the login token, sends every saved answer to the server with
///    retries + backoff, and deletes an answer only after the server accepted it.
///
/// The app never decides that a payment succeeded: it only shows the status the
/// server stored.
class Payments with WidgetsBindingObserver {
  Payments._();
  static final instance = Payments._();

  static const _channel = MethodChannel('cloudstorage/upi');
  static const _openKey = 'upi_open_order';

  /// Bumped after an answer was accepted by the server (screens re-check).
  final reported = ValueNotifier<int>(0);

  bool _started = false;
  bool _flushing = false;
  int _attempt = 0;
  Timer? _retry;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Called once the session is ready (after guest sign-in / saved session).
  void start() {
    if (_started || !supported) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'answer') unawaited(flush());
    });
    unawaited(flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(flush());
  }

  // ------------------------------------------------------------------ pay
  Future<OpenOrder> createOrder(Plan plan) async {
    final res = await Backend.createPaymentOrder(plan.id);
    final order = OpenOrder(
      id: res['order_id'] as String,
      reference: res['reference'] as String,
      amount: res['amount'] as String,
      planName: res['plan_name'] as String? ?? plan.name,
      createdAt: DateTime.now(),
    );
    await _saveOpen(order, res);
    return order;
  }

  /// Opens the UPI app for [order]. Throws [NoUpiAppException] when none.
  Future<void> launch(
    OpenOrder order, {
    required String upiId,
    required String payee,
  }) async {
    if (!supported) {
      throw UnsupportedError('UPI payments work in the Android app only.');
    }
    final uri = upiUri(
      upiId: upiId,
      payee: payee,
      reference: order.reference,
      amount: order.amount,
    );
    try {
      await _channel.invokeMethod('launch', {'orderId': order.id, 'uri': uri});
    } on PlatformException catch (e) {
      if (e.code == 'NO_UPI_APP') throw NoUpiAppException();
      throw StateError('Could not open the UPI app: ${e.message ?? e.code}');
    }
  }

  /// `upi://pay?pa=…&pn=…&tr=…&am=…&cu=INR&tn=<app name> <reference>`
  static String upiUri({
    required String upiId,
    required String payee,
    required String reference,
    required String amount,
  }) {
    String e(String v) => Uri.encodeComponent(v);
    return 'upi://pay?pa=${e(upiId)}&pn=${e(payee)}&tr=${e(reference)}'
        '&am=${e(amount)}&cu=INR&tn=${e('${Config.appName} $reference')}';
  }

  // ------------------------------------------------------------- recovery
  Future<void> _saveOpen(OpenOrder order, Map<String, dynamic> res) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _openKey,
      jsonEncode({
        ...order.toJson(),
        'upi_id': res['upi_id'],
        'payee_name': res['payee_name'],
      }),
    );
  }

  /// UPI ID + payee of the saved open order (from the server's answer).
  Future<(String, String)?> savedPayee() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_openKey);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final upi = j['upi_id'] as String?;
    final payee = j['payee_name'] as String?;
    return upi == null || payee == null ? null : (upi, payee);
  }

  /// The order started on this phone in the last 24 h that is still open on
  /// the server, if any.
  Future<OpenOrder?> openOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_openKey);
    if (raw == null) return null;
    final order = OpenOrder.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    if (DateTime.now().difference(order.createdAt) >
        const Duration(hours: 24)) {
      await prefs.remove(_openKey);
      return null;
    }
    try {
      final server = await Backend.paymentOrder(order.id);
      if (server == null || !server.isOpen) {
        await prefs.remove(_openKey);
        return null;
      }
    } catch (_) {
      // Offline: keep it; the status screen will retry.
    }
    return order;
  }

  /// True when the UPI app was opened for an order whose answer has not been
  /// sent yet (e.g. the app was killed while paying).
  Future<bool> hasUnfinishedPayment() async {
    if (!supported) return false;
    try {
      final launched = await _channel.invokeMethod<String>('launchedOrder');
      final pending = jsonDecode(
        await _channel.invokeMethod<String>('pending') ?? '{}',
      ) as Map<String, dynamic>;
      return launched != null || pending.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- flush
  /// Sends every saved UPI answer to the server. Safe to call any time.
  Future<void> flush() async {
    if (!supported || _flushing) return;
    _flushing = true;
    var failed = false;
    try {
      final pending = jsonDecode(
        await _channel.invokeMethod<String>('pending') ?? '{}',
      ) as Map<String, dynamic>;
      if (pending.isEmpty) {
        _attempt = 0;
        return;
      }
      await _ensureFreshSession();
      for (final entry in pending.entries) {
        final orderId = entry.key;
        final value = Map<String, dynamic>.from(entry.value as Map);
        final raw = value['raw'] as String? ?? 'Status=NO_RESPONSE';
        final at = DateTime.fromMillisecondsSinceEpoch(
          (value['at'] as num?)?.toInt() ?? 0,
        );
        try {
          await Backend.reportPaymentResult(orderId, raw);
          await _channel.invokeMethod('clear', {'orderId': orderId});
          reported.value++;
        } on PostgrestException catch (e) {
          // The order belongs to another account (user logged out/in) or no
          // longer exists. Keep it for a few days in case the original account
          // comes back, then drop it; the owner still sees the order.
          if (e.message.contains('order not found') &&
              DateTime.now().difference(at) > const Duration(days: 3)) {
            await _channel.invokeMethod('clear', {'orderId': orderId});
          } else {
            failed = true;
          }
        } catch (_) {
          failed = true; // offline, server error… retry
        }
      }
    } catch (_) {
      failed = true;
    } finally {
      _flushing = false;
    }
    if (failed) {
      _scheduleRetry();
    } else {
      _attempt = 0;
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    final seconds = min(120, 2 << min(_attempt, 6)); // 2, 4, 8 … 120 s
    _attempt++;
    _retry = Timer(Duration(seconds: seconds), () => unawaited(flush()));
  }

  /// Waits for the saved session and refreshes the token (it may have expired
  /// while the UPI app was open).
  Future<void> _ensureFreshSession() async {
    final auth = Supabase.instance.client.auth;
    for (var i = 0; i < 20 && auth.currentSession == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (auth.currentSession == null) throw StateError('no session yet');
    try {
      await auth.refreshSession();
    } on AuthException {
      if (auth.currentSession!.isExpired) rethrow; // retry later
    }
  }
}

Payments get payments => Payments.instance;
