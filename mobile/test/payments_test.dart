import 'package:cloud_storage/models.dart';
import 'package:cloud_storage/services/payments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UPI link has the exact fields, order and encoding', () {
    final uri = Payments.upiUri(
      upiId: '2728412a@bandhan',
      payee: 'Flixvault',
      reference: 'CS261003ABCDEF123456',
      amount: '129.00',
    );
    expect(
      uri,
      'upi://pay?pa=2728412a%40bandhan&pn=Flixvault&tr=CS261003ABCDEF123456'
      '&am=129.00&cu=INR&tn=Flixvault%20CS261003ABCDEF123456',
    );
    final parsed = Uri.parse(uri);
    expect(parsed.queryParameters['pa'], '2728412a@bandhan');
    expect(parsed.queryParameters['am'], '129.00');
  });

  test('payment order parses server rows', () {
    final o = PaymentOrder.fromJson({
      'id': 'o1',
      'reference': 'CS1',
      'amount_paise': 6900,
      'status': 'pending',
      'client_status': 'NO_RESPONSE',
      'txn_id': null,
      'created_at': '2026-10-03T10:00:00Z',
      'verified_at': null,
      'plans': {'name': 'Trial'},
    });
    expect(o.amountLabel, '₹69.00');
    expect(o.isOpen, isTrue);
    expect(o.planName, 'Trial');
  });
}
