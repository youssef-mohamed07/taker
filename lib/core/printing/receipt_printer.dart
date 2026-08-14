import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

/// One printable line on the receipt
class ReceiptLine {
  final String productName;
  final double quantity;
  final double unitPrice;
  final double total;

  const ReceiptLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}

/// Thermal receipt printing (80mm / 58mm) using the pdf + printing packages.
/// Paper size honors the saved printer prefs (settings → printer dialog).
class ReceiptPrinter {
  ReceiptPrinter._();

  static const double _pointsPerMm = PdfPageFormat.mm;

  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  static Future<pw.Font> _regular() async {
    return _regularFont ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/receipt_arabic.ttf'),
    );
  }

  static Future<pw.Font> _bold() async {
    return _boldFont ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/receipt_arabic_bold.ttf'),
    );
  }

  static String _money(double v) => v.toStringAsFixed(2);

  static String _qty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  /// Opens the system print dialog with the rendered receipt.
  static Future<void> printInvoice({
    required Invoice invoice,
    required List<ReceiptLine> lines,
    String? customerName,
    String? cashierName,
  }) async {
    final doc = await buildInvoiceDocument(
      invoice: invoice,
      lines: lines,
      customerName: customerName,
      cashierName: cashierName,
    );

    await Printing.layoutPdf(
      name: 'فاتورة-${invoice.invoiceNumber}.pdf',
      onLayout: (_) async => doc.save(),
    );
  }

  /// Renders a sample invoice as PDF bytes for the in-app preview
  /// (settings → معاينة الفاتورة). Honors the selected paper size and the
  /// saved store identity.
  static Future<Uint8List> previewInvoice({
    required String paperSize,
    String? customerName,
    String? cashierName,
  }) async {
    final invoice = Invoice(
      id: 0,
      invoiceNumber: '000123',
      userId: 1,
      subtotal: 610,
      discount: 10,
      tax: 0,
      total: 600,
      paid: 500,
      remaining: 100,
      paymentMethod: 'cash',
      status: 'completed',
      createdAt: DateTime.now(),
    );

    const lines = [
      ReceiptLine(productName: 'سكر 1 كيلو', quantity: 2, unitPrice: 50, total: 100),
      ReceiptLine(productName: 'زيت عباد الشمس 1 لتر', quantity: 3, unitPrice: 90, total: 270),
      ReceiptLine(productName: 'مكرونة 400 جم', quantity: 6, unitPrice: 15, total: 90),
      ReceiptLine(productName: 'شاي ناعم 250 جم', quantity: 2, unitPrice: 75, total: 150),
    ];

    final doc = await buildInvoiceDocument(
      invoice: invoice,
      lines: lines,
      customerName: customerName ?? 'عميل تجريبي',
      cashierName: cashierName ?? 'الكاشير',
      paperSize: paperSize,
    );
    return doc.save();
  }

  /// Builds the receipt PDF document. Reads the store identity and paper
  /// size from preferences unless overridden (used by the preview dialog).
  static Future<pw.Document> buildInvoiceDocument({
    required Invoice invoice,
    required List<ReceiptLine> lines,
    String? customerName,
    String? cashierName,
    String? paperSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final size = paperSize ?? prefs.getString('paper_size') ?? '80mm';
    final widthMm = size == '58mm' ? 58.0 : 80.0;

    // Store identity shown in the receipt header (managed from settings)
    final storeName =
        prefs.getString('store_name') ?? 'أبو وائل لتجارة الجملة والقطاعي';
    final phone1 = prefs.getString('store_phone1') ?? '';
    final phone2 = prefs.getString('store_phone2') ?? '';
    final phones = [phone1, phone2]
        .where((p) => p.trim().isNotEmpty)
        .join(' - ');

    final regular = await _regular();
    final bold = await _bold();

    final doc = pw.Document();
    final pageFormat = PdfPageFormat(
      widthMm * _pointsPerMm,
      297 * _pointsPerMm, // tall page; printer cuts to content
      marginAll: 4 * _pointsPerMm,
    );

    final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(invoice.createdAt);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    storeName,
                    style: pw.TextStyle(font: bold, fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                if (phones.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Center(
                      child: pw.Text(
                        'هاتف: $phones',
                        style: pw.TextStyle(font: regular, fontSize: 9),
                      ),
                    ),
                  ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'فاتورة ضريبية مبسطة',
                    style: pw.TextStyle(font: regular, fontSize: 9),
                  ),
                ),
                pw.Divider(),
                _infoRow('رقم الفاتورة:', invoice.invoiceNumber, regular, bold),
                _infoRow('التاريخ:', dateStr, regular, bold),
                if (customerName != null && customerName.isNotEmpty)
                  _infoRow('العميل:', customerName, regular, bold),
                if (cashierName != null && cashierName.isNotEmpty)
                  _infoRow('الكاشير:', cashierName, regular, bold),
                _infoRow(
                  'طريقة الدفع:',
                  invoice.paymentMethod == 'cash'
                      ? 'نقدي'
                      : invoice.paymentMethod == 'card'
                          ? 'فيزا / كارت'
                          : invoice.paymentMethod == 'fawry'
                              ? 'فوري'
                              : 'آجل',
                  regular,
                  bold,
                ),
                if (invoice.status == 'voided')
                  pw.Center(
                    child: pw.Text(
                      '*** فاتورة ملغاة ***',
                      style: pw.TextStyle(font: bold, fontSize: 11),
                    ),
                  ),
                pw.Divider(),

                // Items header
                pw.Row(
                  children: [
                    pw.Expanded(flex: 5, child: _cell('الصنف', bold)),
                    pw.Expanded(flex: 2, child: _cell('الكمية', bold, center: true)),
                    pw.Expanded(flex: 2, child: _cell('السعر', bold, center: true)),
                    pw.Expanded(flex: 3, child: _cell('الإجمالي', bold, center: true)),
                  ],
                ),
                pw.Divider(height: 4),

                // Items
                ...lines.map(
                  (l) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Text(
                            l.productName,
                            style: pw.TextStyle(font: regular, fontSize: 8),
                            maxLines: 2,
                          ),
                        ),
                        pw.Expanded(flex: 2, child: _cell(_qty(l.quantity), regular, center: true)),
                        pw.Expanded(flex: 2, child: _cell(_money(l.unitPrice), regular, center: true)),
                        pw.Expanded(flex: 3, child: _cell(_money(l.total), regular, center: true)),
                      ],
                    ),
                  ),
                ),

                pw.Divider(),

                // Totals
                if (invoice.discount > 0)
                  _totalRow('الخصم:', '-${_money(invoice.discount)}', regular),
                if (invoice.tax > 0)
                  _totalRow('الضريبة:', _money(invoice.tax), regular),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'الإجمالي:',
                      style: pw.TextStyle(font: bold, fontSize: 11),
                    ),
                    pw.Text(
                      '${_money(invoice.total)} ج.م',
                      style: pw.TextStyle(font: bold, fontSize: 11),
                    ),
                  ],
                ),
                _totalRow('المدفوع:', _money(invoice.paid), regular),
                if (invoice.remaining > 0)
                  _totalRow('المتبقي:', _money(invoice.remaining), regular),

                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'شكراً لتعاملكم معنا',
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  static pw.Widget _cell(String text, pw.Font font, {bool center = false}) {
    return pw.Text(
      text,
      style: pw.TextStyle(font: font, fontSize: 8),
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
    );
  }

  static pw.Widget _infoRow(
    String label,
    String value,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 9)),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 9)),
          pw.Text(value, style: pw.TextStyle(font: regular, fontSize: 9)),
        ],
      ),
    );
  }
}
