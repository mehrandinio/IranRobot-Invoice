import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IranRobotApp());
}

String jalaliToday() {
  final date = Jalali.now();
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String newInvoiceNumber() =>
    '${Jalali.now().year}${Jalali.now().month.toString().padLeft(2, '0')}${Jalali.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

double number(String text) =>
    double.tryParse(text.replaceAll(',', '').replaceAll('٫', '.').trim()) ?? 0;

String amount(num value) {
  final v = value.toDouble();
  final formatted = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  return formatted.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
}

class Party {
  String name, economic, registration, postal, province, city, address, phone;
  Party({
    this.name = '',
    this.economic = '',
    this.registration = '',
    this.postal = '',
    this.province = '',
    this.city = '',
    this.address = '',
    this.phone = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name, 'economic': economic, 'registration': registration,
        'postal': postal, 'province': province, 'city': city,
        'address': address, 'phone': phone,
      };

  factory Party.fromJson(Map<String, dynamic> json) => Party(
        name: '${json['name'] ?? ''}',
        economic: '${json['economic'] ?? ''}',
        registration: '${json['registration'] ?? ''}',
        postal: '${json['postal'] ?? ''}',
        province: '${json['province'] ?? ''}',
        city: '${json['city'] ?? ''}',
        address: '${json['address'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
      );
}

class Item {
  String code, description, unit;
  double quantity, price, discount, taxRate;

  Item({
    this.code = '',
    this.description = '',
    this.unit = 'عدد',
    this.quantity = 1,
    this.price = 0,
    this.discount = 0,
    this.taxRate = 0,
  });

  double get subtotal => quantity * price;
  double get discounted => (subtotal - discount).clamp(0, double.infinity).toDouble();
  double get tax => discounted * taxRate / 100;
  double get total => discounted + tax;

  Map<String, dynamic> toJson() => {
        'code': code, 'description': description, 'unit': unit,
        'quantity': quantity, 'price': price,
        'discount': discount, 'taxRate': taxRate,
      };

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        code: '${json['code'] ?? ''}',
        description: '${json['description'] ?? ''}',
        unit: '${json['unit'] ?? 'عدد'}',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0,
      );
}

class Invoice {
  String id, number, date, title, currency, notes, payment;
  Party seller, buyer;
  List<Item> items;

  Invoice({
    required this.id,
    required this.number,
    required this.date,
    required this.title,
    required this.currency,
    required this.notes,
    required this.payment,
    required this.seller,
    required this.buyer,
    required this.items,
  });

  factory Invoice.empty(Party seller) => Invoice(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        number: newInvoiceNumber(),
        date: jalaliToday(),
        title: 'پیش‌فاکتور فروش',
        currency: 'دلار',
        notes: '',
        payment: 'نقدی',
        seller: Party.fromJson(seller.toJson()),
        buyer: Party(),
        items: [Item()],
      );

  double get subTotal => items.fold(0, (double sum, Item item) => sum + item.subtotal);
  double get discount => items.fold(
      0, (double sum, Item item) => sum + item.discount.clamp(0, item.subtotal).toDouble());
  double get tax => items.fold(0, (double sum, Item item) => sum + item.tax);
  double get total => items.fold(0, (double sum, Item item) => sum + item.total);

  Map<String, dynamic> toJson() => {
        'id': id, 'number': number, 'date': date, 'title': title,
        'currency': currency, 'notes': notes, 'payment': payment,
        'seller': seller.toJson(), 'buyer': buyer.toJson(),
        'items': items.map((item) => item.toJson()).toList(),
      };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: '${json['id']}',
        number: '${json['number']}',
        date: '${json['date']}',
        title: '${json['title'] ?? 'پیش‌فاکتور فروش'}',
        currency: '${json['currency'] ?? 'دلار'}',
        notes: '${json['notes'] ?? ''}',
        payment: '${json['payment'] ?? 'نقدی'}',
        seller: Party.fromJson(Map<String, dynamic>.from(json['seller'] ?? {})),
        buyer: Party.fromJson(Map<String, dynamic>.from(json['buyer'] ?? {})),
        items: (json['items'] as List? ?? [])
            .map((item) => Item.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class IranRobotApp extends StatelessWidget {
  const IranRobotApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'پیش‌فاکتور ساز ایران ربات',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa'),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF163B69)),
          fontFamily: 'Vazirmatn',
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: InvoiceHome(),
        ),
      );
}

Widget textField(
  String label,
  String initial,
  ValueChanged<String> onChanged, {
  TextInputType? keyboard,
  int lines = 1,
}) =>
    TextFormField(
      initialValue: initial,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: keyboard,
      maxLines: lines,
      onChanged: onChanged,
    );

class InvoiceHome extends StatefulWidget {
  const InvoiceHome({super.key});

  @override
  State<InvoiceHome> createState() => _InvoiceHomeState();
}

class _InvoiceHomeState extends State<InvoiceHome> {
  List<Invoice> invoices = [];
  Party defaultSeller = Party(name: 'ایران ربات', province: 'تهران', city: 'شهرقدس');
  Uint8List? logo;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final savedSeller = prefs.getString('seller');
      if (savedSeller != null) {
        defaultSeller = Party.fromJson(Map<String, dynamic>.from(jsonDecode(savedSeller)));
      }
      invoices = (jsonDecode(prefs.getString('invoices') ?? '[]') as List)
          .map((item) => Invoice.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final savedLogo = prefs.getString('logo');
      if (savedLogo != null) logo = base64Decode(savedLogo);
    } catch (_) {
      invoices = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seller', jsonEncode(defaultSeller.toJson()));
    await prefs.setString('invoices', jsonEncode(invoices.map((e) => e.toJson()).toList()));
    if (logo != null) await prefs.setString('logo', base64Encode(logo!));
  }

  Future<void> editInvoice([Invoice? existing]) async {
    final invoice = existing == null
        ? Invoice.empty(defaultSeller)
        : Invoice.fromJson(existing.toJson());
    final result = await Navigator.of(context).push<Invoice>(MaterialPageRoute(
        builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: InvoiceEditor(invoice: invoice, logo: logo),
            )));
    if (result == null) return;
    setState(() {
      final index = invoices.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        invoices[index] = result;
      } else {
        invoices.insert(0, result);
      }
    });
    await persist();
  }

  Future<void> editSeller() async {
    final result = await Navigator.of(context).push<Party>(MaterialPageRoute(
        builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: PartyEditor(
                title: 'مشخصات پیش‌فرض فروشنده',
                party: Party.fromJson(defaultSeller.toJson()),
              ),
            )));
    if (result == null) return;
    setState(() => defaultSeller = result);
    await persist();
  }

  Future<void> selectLogo() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 700, imageQuality: 75);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => logo = bytes);
    await persist();
  }

  Future<void> removeInvoice(Invoice invoice) async {
    final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('حذف پیش‌فاکتور؟'),
              content: Text('شماره ${invoice.number} حذف خواهد شد.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('انصراف')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('حذف')),
              ],
            ));
    if (approved != true) return;
    setState(() => invoices.removeWhere((item) => item.id == invoice.id));
    await persist();
  }

  Future<void> duplicate(Invoice invoice) async {
    final clone = Invoice.fromJson(invoice.toJson())
      ..id = DateTime.now().microsecondsSinceEpoch.toString()
      ..number = newInvoiceNumber();
    setState(() => invoices.insert(0, clone));
    await persist();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('پیش‌فاکتور ساز ایران ربات'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (choice) {
                if (choice == 'seller') editSeller();
                if (choice == 'logo') selectLogo();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'seller', child: Text('مشخصات فروشنده')),
                PopupMenuItem(value: 'logo', child: Text('انتخاب لوگو')),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => editInvoice(),
          icon: const Icon(Icons.add),
          label: const Text('پیش‌فاکتور جدید'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : invoices.isEmpty
                ? const Center(child: Text('هنوز پیش‌فاکتوری ثبت نشده است.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: invoices.length,
                    itemBuilder: (_, index) {
                      final invoice = invoices[index];
                      return Card(
                          child: ListTile(
                        onTap: () => editInvoice(invoice),
                        title: Text('${invoice.number} | ${invoice.buyer.name.isEmpty ? 'خریدار نامشخص' : invoice.buyer.name}'),
                        subtitle: Text('${invoice.date} • ${amount(invoice.total)} ${invoice.currency}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (option) async {
                            if (option == 'pdf') {
                              await PdfExport.printInvoice(invoice, logo);
                            } else if (option == 'copy') {
                              await duplicate(invoice);
                            } else if (option == 'delete') {
                              await removeInvoice(invoice);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'pdf', child: Text('نمایش / چاپ / اشتراک PDF')),
                            PopupMenuItem(value: 'copy', child: Text('تکثیر')),
                            PopupMenuItem(value: 'delete', child: Text('حذف')),
                          ],
                        ),
                      ));
                    },
                  ),
      );
}

class PartyEditor extends StatefulWidget {
  const PartyEditor({super.key, required this.party, required this.title});
  final Party party;
  final String title;

  @override
  State<PartyEditor> createState() => _PartyEditorState();
}

class _PartyEditorState extends State<PartyEditor> {
  late Party party;

  @override
  void initState() {
    super.initState();
    party = Party.fromJson(widget.party.toJson());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [
          TextButton(onPressed: () => Navigator.pop(context, party), child: const Text('تأیید')),
        ]),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            textField('نام شخص حقیقی / حقوقی', party.name, (v) => party.name = v),
            const SizedBox(height: 12),
            textField('شماره اقتصادی', party.economic, (v) => party.economic = v),
            const SizedBox(height: 12),
            textField('شماره ثبت / شناسه ملی', party.registration, (v) => party.registration = v),
            const SizedBox(height: 12),
            textField('کدپستی', party.postal, (v) => party.postal = v),
            const SizedBox(height: 12),
            textField('استان', party.province, (v) => party.province = v),
            const SizedBox(height: 12),
            textField('شهر', party.city, (v) => party.city = v),
            const SizedBox(height: 12),
            textField('تلفن', party.phone, (v) => party.phone = v),
            const SizedBox(height: 12),
            textField('نشانی کامل', party.address, (v) => party.address = v, lines: 3),
          ],
        ),
      );
}

class InvoiceEditor extends StatefulWidget {
  const InvoiceEditor({super.key, required this.invoice, this.logo});
  final Invoice invoice;
  final Uint8List? logo;

  @override
  State<InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<InvoiceEditor> {
  late Invoice invoice;

  @override
  void initState() {
    super.initState();
    invoice = widget.invoice;
  }

  void save() {
    if (invoice.number.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شماره پیش‌فاکتور الزامی است')));
      return;
    }
    Navigator.pop(context, invoice);
  }

  Future<void> editParty(bool buyer) async {
    final party = buyer ? invoice.buyer : invoice.seller;
    final result = await Navigator.push<Party>(
        context,
        MaterialPageRoute(
            builder: (_) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: PartyEditor(
                    title: buyer ? 'مشخصات خریدار' : 'مشخصات فروشنده',
                    party: party,
                  ),
                )));
    if (result == null) return;
    setState(() {
      if (buyer) {
        invoice.buyer = result;
      } else {
        invoice.seller = result;
      }
    });
  }

  Future<void> editItem([int? index]) async {
    final current = index == null
        ? Item()
        : Item.fromJson(invoice.items[index].toJson());
    final updated = await Navigator.push<Item>(
        context,
        MaterialPageRoute(
            builder: (_) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: ItemEditor(item: current),
                )));
    if (updated == null) return;
    setState(() {
      if (index == null) {
        invoice.items.add(updated);
      } else {
        invoice.items[index] = updated;
      }
    });
  }

  Widget summary(String title, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            Text('${amount(value)} ${invoice.currency}',
                style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ویرایش پیش‌فاکتور'), actions: [
          IconButton(
              tooltip: 'نمایش PDF',
              onPressed: () => PdfExport.printInvoice(invoice, widget.logo),
              icon: const Icon(Icons.picture_as_pdf)),
          TextButton(onPressed: save, child: const Text('ذخیره')),
        ]),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  textField('عنوان پیش‌فاکتور', invoice.title, (v) => invoice.title = v),
                  const SizedBox(height: 10),
                  textField('شماره', invoice.number, (v) => invoice.number = v),
                  const SizedBox(height: 10),
                  textField('تاریخ شمسی', invoice.date, (v) => invoice.date = v),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: invoice.currency,
                    decoration: const InputDecoration(
                        labelText: 'واحد پول', border: OutlineInputBorder()),
                    items: ['دلار', 'یورو', 'تومان', 'ریال']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => invoice.currency = v ?? 'دلار'),
                  ),
                ]),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('خریدار'),
                subtitle: Text(invoice.buyer.name.isEmpty ? 'ثبت مشخصات خریدار' : invoice.buyer.name),
                trailing: const Icon(Icons.edit),
                onTap: () => editParty(true),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('فروشنده'),
                subtitle: Text(invoice.seller.name),
                trailing: const Icon(Icons.edit),
                onTap: () => editParty(false),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(
                  child: Text('اقلام کالا و خدمات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              FilledButton.tonalIcon(
                  onPressed: () => editItem(),
                  icon: const Icon(Icons.add),
                  label: const Text('افزودن ردیف')),
            ]),
            ...invoice.items.asMap().entries.map((entry) => Card(
                  child: ListTile(
                    onTap: () => editItem(entry.key),
                    title: Text(entry.value.description.isEmpty
                        ? 'ردیف ${entry.key + 1}'
                        : entry.value.description),
                    subtitle: Text(
                        '${amount(entry.value.quantity)} ${entry.value.unit} × ${amount(entry.value.price)} = ${amount(entry.value.total)} ${invoice.currency}'),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => invoice.items.removeAt(entry.key))),
                  ),
                )),
            const Divider(),
            summary('جمع ناخالص', invoice.subTotal),
            summary('تخفیف', invoice.discount),
            summary('مالیات و عوارض', invoice.tax),
            summary('مبلغ نهایی', invoice.total, bold: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                initialValue: invoice.payment,
                decoration: const InputDecoration(
                    labelText: 'شرایط فروش', border: OutlineInputBorder()),
                items: ['نقدی', 'غیرنقدی', 'توافقی']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => invoice.payment = v ?? 'نقدی'),
            const SizedBox(height: 12),
            textField('توضیحات و شرایط', invoice.notes, (v) => invoice.notes = v, lines: 3),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: save,
                icon: const Icon(Icons.save),
                label: const Text('ذخیره پیش‌فاکتور')),
            const SizedBox(height: 60),
          ],
        ),
      );
}

class ItemEditor extends StatefulWidget {
  const ItemEditor({super.key, required this.item});
  final Item item;
  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  late Item item;

  @override
  void initState() {
    super.initState();
    item = Item.fromJson(widget.item.toJson());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('کالا / خدمات'), actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, item),
              child: const Text('تأیید')),
        ]),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            textField('شرح کالا یا خدمات', item.description, (v) => item.description = v, lines: 2),
            const SizedBox(height: 12),
            textField('کد کالا', item.code, (v) => item.code = v),
            const SizedBox(height: 12),
            textField('واحد اندازه‌گیری', item.unit, (v) => item.unit = v),
            const SizedBox(height: 12),
            textField('تعداد / مقدار', amount(item.quantity), (v) => item.quantity = number(v),
                keyboard: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            textField('قیمت واحد', amount(item.price), (v) => item.price = number(v),
                keyboard: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            textField('تخفیف مبلغی', amount(item.discount),
                (v) => item.discount = number(v).clamp(0, double.infinity).toDouble(),
                keyboard: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            textField('درصد مالیات', amount(item.taxRate),
                (v) => item.taxRate = number(v).clamp(0, 100).toDouble(),
                keyboard: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: () => Navigator.pop(context, item),
                child: const Text('ذخیره ردیف')),
          ],
        ),
      );
}

class PdfExport {
  static Future<void> printInvoice(Invoice invoice, Uint8List? logo) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    final doc = pw.Document(theme: pw.ThemeData.withFont(
        base: regular, bold: bold, fontFallback: [regular]));

    pw.Widget label(String value, {bool strong = false, double size = 8}) =>
        pw.Text(value,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(font: strong ? bold : regular, fontSize: size));

    pw.Widget pair(String title, String value) => pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
            label('$title: ', strong: true),
            pw.Flexible(child: label(value)),
          ]),
        );

    pw.Widget party(String title, Party person) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(5),
                child: pw.Center(child: label(title, strong: true, size: 10))),
            pw.Wrap(spacing: 12, children: [
              pair('نام', person.name),
              pair('شماره اقتصادی', person.economic),
              pair('شناسه ملی / ثبت', person.registration),
              pair('کد پستی', person.postal),
              pair('استان', person.province),
              pair('شهر', person.city),
              pair('تلفن', person.phone),
            ]),
            pair('نشانی', person.address),
          ],
        );

    pw.Widget cell(String value, {bool strong = false}) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
          child: label(value, strong: strong, size: 7),
        );

    final headers = [
      'ردیف', 'کد کالا', 'شرح کالا یا خدمات', 'تعداد', 'واحد',
      'قیمت واحد (${invoice.currency})', 'مبلغ کل', 'تخفیف',
      'بعد از تخفیف', 'مالیات', 'جمع کل'
    ];
    final data = invoice.items.asMap().entries.map((entry) {
      final item = entry.value;
      return [
        '${entry.key + 1}', item.code, item.description, amount(item.quantity),
        item.unit, amount(item.price), amount(item.subtotal),
        amount(item.discount), amount(item.discounted),
        amount(item.tax), amount(item.total)
      ];
    }).toList();

    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(.5),
      1: const pw.FlexColumnWidth(.8),
      2: const pw.FlexColumnWidth(3.5),
      3: const pw.FlexColumnWidth(.65),
      4: const pw.FlexColumnWidth(.7),
      5: const pw.FlexColumnWidth(1.15),
      6: const pw.FlexColumnWidth(1.15),
      7: const pw.FlexColumnWidth(.9),
      8: const pw.FlexColumnWidth(1.15),
      9: const pw.FlexColumnWidth(.9),
      10: const pw.FlexColumnWidth(1.15),
    };

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      textDirection: pw.TextDirection.rtl,
      header: (context) => pw.Column(children: [
        pw.Row(children: [
          if (logo != null) pw.Image(pw.MemoryImage(logo), width: 52, height: 52),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Column(children: [
            label(invoice.seller.name, strong: true, size: 13),
            label(invoice.title, strong: true, size: 11),
          ])),
          pw.Column(children: [
            pair('شماره', invoice.number),
            pair('تاریخ', invoice.date),
          ]),
        ]),
        pw.SizedBox(height: 9),
      ]),
      footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            label('ایران ربات'),
            label('صفحه ${context.pageNumber} از ${context.pagesCount}'),
          ]),
      build: (context) => [
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: party('مشخصات فروشنده', invoice.seller)),
        pw.SizedBox(height: 7),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: party('مشخصات خریدار', invoice.buyer)),
        pw.SizedBox(height: 9),
        pw.Center(child: label('مشخصات کالا یا خدمات مورد معامله', strong: true, size: 10)),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: .5),
          columnWidths: widths,
          children: [
            pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: headers.map((heading) => cell(heading, strong: true)).toList()),
            ...data.map((row) => pw.TableRow(
                children: row.map((value) => cell(value)).toList())),
            pw.TableRow(children: [
              cell(''), cell(''), cell('جمع کل', strong: true),
              cell(''), cell(''), cell(''),
              cell(amount(invoice.subTotal), strong: true),
              cell(amount(invoice.discount), strong: true),
              cell(amount(invoice.subTotal - invoice.discount), strong: true),
              cell(amount(invoice.tax), strong: true),
              cell(amount(invoice.total), strong: true),
            ]),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          label('مبلغ نهایی: ${amount(invoice.total)} ${invoice.currency}',
              strong: true, size: 12),
          label('شرایط فروش: ${invoice.payment}', strong: true),
        ]),
        pw.SizedBox(height: 8),
        pair('توضیحات', invoice.notes),
        pw.SizedBox(height: 30),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
          label('مهر و امضای فروشنده', strong: true),
          label('مهر و امضای خریدار', strong: true),
        ]),
      ],
    ));

    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'IranRobot-${invoice.number}.pdf',
    );
  }
}