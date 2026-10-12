import 'package:flutter_test/flutter_test.dart';
import 'package:iranrobot_invoice/main.dart';
void main() {
  test('line subtotal, discount, and percentage tax', () {
    final i = Item(quantity: 2, price: 17000, discount: 4000, taxRate: 10);
    expect(i.subtotal, 34000);
    expect(i.discounted, 30000);
    expect(i.tax, 3000);
    expect(i.total, 33000);
  });
  test('invoice totals survive JSON serialization', () {
    final i = Invoice.empty(Party(name: 'ایران ربات'));
    i.items = [Item(quantity: 2, price: 17000), Item(quantity: 2, price: 5800)];
    expect(i.total, 45600);
    expect(Invoice.fromJson(i.toJson()).total, 45600);
  });
}
