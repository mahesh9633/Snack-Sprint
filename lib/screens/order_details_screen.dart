import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_color.dart';
import '../model/product_model.dart' show Product;
import '../products/product_detail_screen.dart';
import '../services/session_manager.dart';
import '../services/api_config_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;
  pw.ThemeData? _cachedPdfTheme;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _preloadPdfFonts();
  }

  Future<void> _preloadPdfFonts() async {
    try {
      _cachedPdfTheme ??= pw.ThemeData.withFont(
        base:       await PdfGoogleFonts.nunitoRegular(),
        bold:       await PdfGoogleFonts.nunitoBold(),
        italic:     await PdfGoogleFonts.nunitoItalic(),
        boldItalic: await PdfGoogleFonts.nunitoBoldItalic(),
      );
    } catch (_) {}
  }

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {

      final token = await SessionManager.getToken() ?? '';
      final uri = Uri.parse(
        '${ApiConfig.indexPhp}'
            '?route=groceries/categories.getOrdersbyId'
            '&token=$token'
            '&order_id=${widget.orderId}',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          setState(() {
            _data = json['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = json['message'] ?? 'Failed to load order';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // ── PDF Generator ────────────────────────────────────────────────────────────
  Future<Uint8List> _buildPdf() async {
    final orderInfo     = _data!['order_info']   as Map<String, dynamic>;
    final invoiceNo     = orderInfo['invoice_no']?.toString()     ?? '';
    final invoicePrefix = orderInfo['invoice_prefix']?.toString() ?? '';
    final fullInvoice   = '$invoicePrefix$invoiceNo';
    final products      = (_data!['products']    as List?)?.cast<Map<String, dynamic>>() ?? [];
    final invoice    = _data!['invoice']      as Map<String, dynamic>?;
    final taxDetails = (_data!['tax_details'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final history    = (_data!['history']     as List?)?.cast<Map<String, dynamic>>() ?? [];

    final name   = '${orderInfo['firstname'] ?? ''} ${orderInfo['lastname'] ?? ''}'.trim();
    final phone  = orderInfo['telephone']?.toString() ?? '';
    final email  = orderInfo['email']?.toString() ?? '';
    final status = orderInfo['order_status'] ?? '';
    final date   = _formatDate(orderInfo['date_added'] ?? '');

    String paymentMethod = 'N/A';
    try {
      final pmRaw = orderInfo['payment_method']?.toString() ?? '';
      if (pmRaw.isNotEmpty) {
        final pm = jsonDecode(pmRaw);
        paymentMethod = pm['name'] ?? 'N/A';
      }
    } catch (_) {}

    double subTotal = 0, totalTax = 0, discount = 0,
        roundoff = 0, grandTotal = 0,
        cashAmt = 0, upiAmt = 0, takeawayAmt = 0;
    String couponCode = '', upiRef = '';

    double delivery = 0;
    if (invoice != null) {
      subTotal   = double.tryParse(invoice['sub_total'].toString())       ?? 0;
      totalTax   = double.tryParse(invoice['total_tax'].toString())       ?? 0;
      discount   = double.tryParse(invoice['discount'].toString())        ?? 0;
      roundoff   = double.tryParse(invoice['roundoff_amount'].toString()) ?? 0;
      grandTotal = double.tryParse(invoice['total_received'].toString())  ?? 0;
      cashAmt      = double.tryParse(invoice['cash_amount'].toString())      ?? 0;
      upiAmt       = double.tryParse(invoice['upi_amount'].toString())       ?? 0;
      takeawayAmt  = double.tryParse(invoice['takeaway_amount'].toString())  ?? 0;
      upiRef       = invoice['upi_ref']?.toString() ?? '';
      couponCode   = invoice['coupon']?.toString() ?? '';
      delivery     = takeawayAmt;
    }

    const purple      = PdfColor(0.722, 0.361, 0.000);   // #B85C00
    const purpleLight = PdfColor(0.996, 0.945, 0.878);   // #FFF1E0
    const purpleBg    = PdfColor(1.000, 0.973, 0.941);   // #FFF8F0
    const green       = PdfColor(0.133, 0.545, 0.133);   // green700
    const greenLight  = PdfColor(0.878, 0.973, 0.878);   // green100
    const orange      = PdfColor(1.000, 0.596, 0.000);   // orange
    const red         = PdfColor(0.863, 0.078, 0.235);   // red
    const blue        = PdfColor(0.098, 0.463, 0.824);   // blue
    const grey600     = PdfColor(0.420, 0.420, 0.420);
    const grey700     = PdfColor(0.310, 0.310, 0.310);
    const grey400     = PdfColor(0.620, 0.620, 0.620);
    const grey200     = PdfColor(0.800, 0.800, 0.800);
    const black87     = PdfColor(0.129, 0.129, 0.129);

    // Dynamic status colour
    PdfColor statusPdfColor(String s) {
      switch (s.toLowerCase()) {
        case 'complete':
        case 'completed':   return green;
        case 'canceled':
        case 'cancelled':   return red;
        case 'pending':     return orange;
        case 'processing':  return blue;
        default:            return purple;
      }
    }

    PdfColor statusPdfBg(String s) {
      switch (s.toLowerCase()) {
        case 'complete':
        case 'completed':   return greenLight;
        case 'canceled':
        case 'cancelled':   return PdfColor(1.0, 0.9, 0.9);
        case 'pending':     return PdfColor(1.0, 0.95, 0.8);
        case 'processing':  return PdfColor(0.88, 0.94, 1.0);
        default:            return purpleLight;
      }
    }

    final statusFg = statusPdfColor(status);
    final statusBg = statusPdfBg(status);

    // ── Force colour mode on the document ────────────────────────────────────
    _cachedPdfTheme ??= pw.ThemeData.withFont(
      base:       await PdfGoogleFonts.nunitoRegular(),
      bold:       await PdfGoogleFonts.nunitoBold(),
      italic:     await PdfGoogleFonts.nunitoItalic(),
      boldItalic: await PdfGoogleFonts.nunitoBoldItalic(),
    );

    final pdf = pw.Document(theme: _cachedPdfTheme);

    // ── helper: compact bill row ──────────────────────────────────────────────
    pw.Widget cRow(String label, String value,
        {PdfColor lc = black87, PdfColor vc = black87}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: lc)),
              pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: vc)),
            ],
          ),
        );

    // ── helper: compact section header ───────────────────────────────────────
    pw.Widget secHead(String t, PdfColor accent, PdfColor bg) =>
        pw.Row(children: [
          pw.Container(width: 4, height: 22,
              decoration: pw.BoxDecoration(color: accent,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)))),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: bg,
              child: pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: accent)),
            ),
          ),
        ]);

    // ── helper: compact info box wrapper ─────────────────────────────────────
    pw.Widget box(pw.Widget child) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: grey200, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: child,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            // ── TOP HEADER BAR ──────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const pw.BoxDecoration(
                color: purple,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Smile Basket', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text('Order Receipt', style: pw.TextStyle(fontSize: 10, color: PdfColor(0.85, 0.80, 1.0))),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('Order #${widget.orderId}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text('Invoice: ${(orderInfo['invoice_prefix'] ?? '')}${(orderInfo['invoice_no'] ?? '')}', style: pw.TextStyle(fontSize: 10, color: PdfColor(0.85, 0.80, 1.0))),
                    pw.Text(date, style: pw.TextStyle(fontSize: 10, color: PdfColor(0.85, 0.80, 1.0))),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // ── STATUS BADGE ────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: statusBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                border: pw.Border.all(color: statusFg, width: 0.8),
              ),
              child: pw.Text(status, style: pw.TextStyle(color: statusFg, fontWeight: pw.FontWeight.bold, fontSize: 10)),
            ),
            pw.SizedBox(height: 8),

            // ── ITEMS TABLE ──────────────────────────────────────────────────
            secHead('Items Ordered', purple, purpleLight),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: grey200, width: 0.6),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: purple),
                  children: [
                    _pdfCell('Item',       headerRow: true),
                    _pdfCell('Qty',        headerRow: true),
                    _pdfCell('Unit Price', headerRow: true),
                    _pdfCell('Total',      headerRow: true),
                  ],
                ),
                for (var i = 0; i < products.length; i++)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : purpleBg),
                    children: [
                      _pdfCell(products[i]['name'] ?? '', labelColor: black87),
                      _pdfCell('${products[i]['quantity'] ?? 1}', labelColor: black87),
                      _pdfCell('Rs.${_fmt(double.tryParse(products[i]['price'].toString()) ?? 0)}', labelColor: black87),
                      _pdfCell('Rs.${_fmt(double.tryParse(products[i]['total'].toString()) ?? 0)}', labelColor: purple, isBold: true),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 8),

            // ── MIDDLE ROW: Bill Summary (left) + Payment & Customer (right) ─
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                // LEFT: Bill Summary
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    // ── BILL SUMMARY (full width) ────────────────────────────────────
                    secHead('Bill Summary', purple, purpleLight),
                    pw.SizedBox(height: 4),
                    box(pw.Column(children: [
                      cRow('Subtotal', 'Rs.${_fmt(subTotal)}'),
                      if (taxDetails.isNotEmpty)
                        for (final t in taxDetails)
                          cRow(t['name'] ?? 'Tax',
                              'Rs.${_fmt(double.tryParse(t['value'].toString()) ?? 0)}',
                              lc: grey600, vc: grey600)
                      else
                        cRow('Tax', 'Rs.${_fmt(totalTax)}', lc: grey600, vc: grey600),
                      if (discount > 0)
                        cRow(couponCode.isNotEmpty ? 'Coupon ($couponCode)' : 'Discount',
                            '-Rs.${_fmt(discount)}', lc: green, vc: green),
                      if (roundoff != 0)
                        cRow('Round Off', 'Rs.${_fmt(roundoff)}', lc: grey600, vc: grey600),
                      if (delivery > 0)
                        cRow('Delivery Charges', 'Rs.${_fmt(delivery)}', lc: grey600, vc: grey600),
                      pw.Divider(color: grey400, thickness: 0.8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                        decoration: const pw.BoxDecoration(
                          color: purpleLight,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Paid', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: purple)),
                            pw.Text('Rs.${_fmt(grandTotal)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: purple)),
                          ],
                        ),
                      ),
                    ])),
                    pw.SizedBox(height: 8),

                    secHead('Payment Details', blue, PdfColor(0.88, 0.94, 1.0)),
                    pw.SizedBox(height: 4),
                    box(pw.Column(children: [
                      cRow('Method', paymentMethod, lc: grey700, vc: blue),
                      if (cashAmt > 0) cRow('Cash', 'Rs.${_fmt(cashAmt)}', lc: grey700, vc: black87),
                      if (upiAmt  > 0) cRow('UPI',  'Rs.${_fmt(upiAmt)}',  lc: grey700, vc: black87),
                      if (upiRef.isNotEmpty && upiRef != 'null')
                        cRow('UPI Ref', upiRef, lc: grey700, vc: black87),
                      if (discount > 0)
                        cRow(
                          couponCode.isNotEmpty ? 'Coupon ($couponCode)' : 'Discount',
                          '-Rs.${_fmt(discount)}',
                          lc: green,
                          vc: green,
                        ),
                      if (delivery > 0)
                        cRow('Delivery Charges', 'Rs.${_fmt(delivery)}', lc: grey600, vc: grey600),
                      pw.Divider(color: grey400, thickness: 0.8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                        decoration: const pw.BoxDecoration(
                          color: purpleLight,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Amount', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: purple)),
                            pw.Text('Rs.${_fmt(grandTotal)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: purple)),
                          ],
                        ),
                      ),
                    ])),
                    pw.SizedBox(height: 8),

                    secHead('Customer Info', green, greenLight),
                    pw.SizedBox(height: 4),
                    box(pw.Column(children: [
                      if (name.isNotEmpty)  cRow('Name',  name,         lc: grey700, vc: black87),
                      if (phone.isNotEmpty) cRow('Phone', '+91 $phone', lc: grey700, vc: black87),
                      if (email.isNotEmpty) cRow('Email', email,        lc: grey700, vc: black87),
                    ])),
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // ── ORDER TIMELINE ───────────────────────────────────────────────
            if (history.isNotEmpty) ...[
              secHead('Order Timeline', orange, PdfColor(1.0, 0.95, 0.8)),
              pw.SizedBox(height: 4),
              box(pw.Row(
                children: history.map((h) {
                  final hStatus = h['status_name'] ?? '';
                  final hColor  = statusPdfColor(hStatus);
                  final hBg     = statusPdfBg(hStatus);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 12),
                    child: pw.Row(children: [
                      pw.Container(
                        width: 8, height: 8,
                        decoration: pw.BoxDecoration(color: hColor, shape: pw.BoxShape.circle),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: hBg,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                            border: pw.Border.all(color: hColor, width: 0.6),
                          ),
                          child: pw.Text(hStatus, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: hColor)),
                        ),
                        pw.Text(_formatDate(h['date_added'] ?? ''),
                            style: pw.TextStyle(fontSize: 8, color: grey400)),
                      ]),
                    ]),
                  );
                }).toList(),
              )),
              pw.SizedBox(height: 8),
            ],

            // ── FOOTER ──────────────────────────────────────────────────────
            pw.Expanded(child: pw.SizedBox()),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              decoration: const pw.BoxDecoration(
                color: purpleLight,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Center(
                child: pw.Text(
                  'Thank you for shopping with Smile Basket!',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: purple, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfCell(String text,
      {bool headerRow = false,
        bool isBold = false,
        PdfColor? labelColor}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: headerRow
                    ? PdfColors.white
                    : (labelColor ?? const PdfColor(0.129, 0.129, 0.129)))),
      );

  Future<void> _downloadPdf() async {
    _showLoader();
    try {
      final pdfBytes = await _buildPdf();
      if (!mounted) return;
      Navigator.pop(context);

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Order_${widget.orderId}.pdf',
        dynamicLayout: true,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnack('Failed to generate PDF: $e');
      }
    }
  }

  // ── Share PDF → native share sheet (WhatsApp, email, Drive, etc.) ────────────
  Future<void> _sharePdf() async {
    _showLoader();
    try {
      final pdfBytes = await _buildPdf();
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/Order_${widget.orderId}.pdf');
      await file.writeAsBytes(pdfBytes);

      if (!mounted) return;
      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Order #${widget.orderId} - MTL Groceries',
        text: 'Receipt for Order #${widget.orderId} from MTL Groceries.',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnack('Failed to share: $e');
      }
    }
  }

  void _showLoader() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue)),
  );

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Order #${widget.orderId}',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),

      // ── Bottom Action Bar (only shown when data is loaded) ──────────────────
      bottomNavigationBar: _data == null
          ? null
          : Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        child: Row(
          children: [
            // Share button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sharePdf,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.buttonPrimary,
                  side: const BorderSide(color: AppColors.buttonPrimary, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Download PDF button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download PDF',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ),
      ),

      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.loader))
          : _error != null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _fetchOrderDetails,
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonPrimary),
        child:
        const Text('Retry', style: TextStyle(color: Colors.white)),
      ),
    ]),
  );

  Widget _buildContent() {
    final orderInfo  = _data!['order_info']   as Map<String, dynamic>;
    final invoiceNo     = orderInfo['invoice_no']?.toString()     ?? '';
    final invoicePrefix = orderInfo['invoice_prefix']?.toString() ?? '';
    final fullInvoice   = '$invoicePrefix$invoiceNo';
    final products   = (_data!['products']    as List?)?.cast<Map<String, dynamic>>() ?? [];
    final invoice    = _data!['invoice']      as Map<String, dynamic>?;
    final taxDetails = (_data!['tax_details'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final history    = (_data!['history']     as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      onRefresh: _fetchOrderDetails,
      color: AppColors.loader,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildStatusCard(orderInfo),
          const SizedBox(height: 12),
          _buildProductsCard(products),
          const SizedBox(height: 12),
          if (invoice != null) ...[
            _buildInvoiceCard(invoice, taxDetails),
            const SizedBox(height: 12),
          ],
          _buildPaymentCard(orderInfo, invoice),
          const SizedBox(height: 12),
          _buildCustomerCard(orderInfo),
          const SizedBox(height: 12),
          if (history.isNotEmpty) ...[
            _buildHistoryCard(history),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> info) {
    final status    = info['order_status'] ?? 'Unknown';
    final dateAdded = info['date_added']   ?? '';
    final invoiceNo =
        '${info['invoice_prefix'] ?? ''}${info['invoice_no'] ?? ''}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long,
                color: AppColors.primaryOrange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${info['order_id']}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  if (invoiceNo.isNotEmpty)
                    Text('Invoice: $invoiceNo',
                        style: TextStyle(
                            fontSize: 12, color: Colors.black87)),
                ]),
          ),
          _statusChip(status),
        ]),
        const SizedBox(height: 12),
        _infoRow(Icons.calendar_today_outlined, 'Date',
            _formatDate(dateAdded)),
      ]),
    );
  }

  Widget _buildProductsCard(List<Map<String, dynamic>> products) {
    return _card(
      title: 'Items Ordered',
      icon: Icons.shopping_basket_outlined,
      child: Column(
        children: products.map((p) {
          final qty   = p['quantity'] ?? '1';
          final price = double.tryParse(p['price'].toString()) ?? 0;
          final total = double.tryParse(p['total'].toString()) ?? 0;
          final gst   = p['gst']?.toString() ?? '0';
          final productId = p['product_id']?.toString() ?? '';

          return GestureDetector(

            onTap: productId.isNotEmpty ? () {
              final rawImg = (p['product_image'] ?? p['image'])?.toString()?.trim() ?? '';
              final fixedUrl = rawImg.startsWith('http')
                  ? rawImg
                  : rawImg.isNotEmpty && rawImg != 'no_image.png'
                  ? '${ApiConfig.imageBase}$rawImg'
                  : '';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(
                    product: Product(
                      id:           productId,
                      name:         p['name'] ?? '',
                      price:        double.tryParse(p['price'].toString()) ?? 0,
                      originalPrice: double.tryParse(p['price'].toString()) ?? 0,
                      image:        rawImg,
                      imageUrl:     fixedUrl,
                      category:     '',
                      quantity:     (int.tryParse(p['quantity']?.toString() ?? '') ?? 0) > 0 ? int.tryParse(p['quantity'].toString())! : 1,
                      posQuantity:  (int.tryParse(p['quantity']?.toString() ?? '') ?? 0) > 0 ? int.tryParse(p['quantity'].toString())! : 1,
                      deliveryTime: '',
                    ),
                  ),
                ),
              );
            } : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF000000).withOpacity(0.15)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                    if ((p['model'] ?? '').toString().isNotEmpty)
                      Text('Model: ${p['model']}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Row(children: [
                      _pill('Qty: $qty'),
                      const SizedBox(width: 8),
                      _pill('GST: $gst%'),
                      const Spacer(),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${_fmt(price)}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black87)),
                            Text('₹${_fmt(total)}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.appBarText)),
                          ]),
                    ]),]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInvoiceCard(
      Map<String, dynamic> inv, List<Map<String, dynamic>> taxes) {
    final subTotal   = double.tryParse(inv['sub_total'].toString())       ?? 0;
    final totalTax   = double.tryParse(inv['total_tax'].toString())       ?? 0;
    final discount   = double.tryParse(inv['discount'].toString())        ?? 0;
    final roundoff   = double.tryParse(inv['roundoff_amount'].toString()) ?? 0;
    final grandTotal = double.tryParse(inv['total_received'].toString())  ?? 0;
    final couponCode = inv['coupon']?.toString() ?? '';

    // delivery = grandTotal - (subTotal + tax - discount + roundoff)
    final delivery = double.tryParse(inv['takeaway_amount']?.toString() ?? '0') ?? 0;

    return _card(
      title: 'Bill Summary',
      icon: Icons.summarize_outlined,
      child: Column(children: [
        _billRow('Subtotal', subTotal),
        if (taxes.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...taxes.map((t) => _billRow(
              t['name'] ?? 'Tax',
              double.tryParse(t['value'].toString()) ?? 0,
              color: Colors.grey[700])),
        ] else
          _billRow('Tax', totalTax, color: Colors.grey[700]),
        if (discount > 0) ...[
          const SizedBox(height: 4),
          _billRow(
            couponCode.isNotEmpty ? 'Coupon ($couponCode)' : 'Discount',
            -discount,
            color: Colors.green[700],
          ),
        ],
        if (roundoff != 0) ...[
          const SizedBox(height: 4),
          _billRow('Round Off', roundoff, color: Colors.grey[600]),
        ],
        // Always show delivery charges row
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.local_shipping_outlined,
              size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Delivery Charges',
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ),
          Text(
            delivery > 0 ? '₹${_fmt(delivery)}' : '₹0.00',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: delivery > 0 ? Colors.grey[700] : Colors.grey[400]),
          ),
        ]),
        const Divider(height: 20),
        Row(children: [
          const Text('Total Paid',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('₹${_fmt(grandTotal)}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue)),
        ]),
      ]),
    );
  }

  Widget _buildPaymentCard(
      Map<String, dynamic> info, Map<String, dynamic>? inv) {
    String paymentMethod = 'N/A';
    try {
      final pmRaw = info['payment_method']?.toString() ?? '';
      if (pmRaw.isNotEmpty) {
        final pm = jsonDecode(pmRaw);
        paymentMethod = pm['name'] ?? 'N/A';
      }
    } catch (_) {}

    final cashAmt =
        double.tryParse(inv?['cash_amount']?.toString() ?? '0') ?? 0;
    final upiAmt =
        double.tryParse(inv?['upi_amount']?.toString() ?? '0') ?? 0;
    final upiRef  = inv?['upi_ref']?.toString() ?? '';
    final pending =
        double.tryParse(inv?['pending_amount']?.toString() ?? '0') ?? 0;
    final grandTotal  = double.tryParse(inv?['total_received']?.toString() ?? '0') ?? 0;
    final subTotal    = double.tryParse(inv?['sub_total']?.toString() ?? '0') ?? 0;
    final totalTax    = double.tryParse(inv?['total_tax']?.toString() ?? '0') ?? 0;
    final discount    = double.tryParse(inv?['discount']?.toString() ?? '0') ?? 0;
    final roundoff    = double.tryParse(inv?['roundoff_amount']?.toString() ?? '0') ?? 0;
    final delivery    = double.tryParse(inv?['takeaway_amount']?.toString() ?? '0') ?? 0;
    final couponCode  = inv?['coupon']?.toString() ?? '';

    return _card(
      title: 'Payment Details',
      icon: Icons.payment_outlined,
      child: Column(children: [
        _infoRow(Icons.payments_outlined, 'Method', paymentMethod),
        if (cashAmt > 0) ...[
          const SizedBox(height: 8),
          _infoRow(Icons.money, 'Cash', '₹${_fmt(cashAmt)}'),
        ],
        if (upiAmt > 0) ...[
          const SizedBox(height: 8),
          _infoRow(Icons.qr_code, 'UPI', '₹${_fmt(upiAmt)}'),
        ],
        if (upiRef.isNotEmpty && upiRef != 'null') ...[
          const SizedBox(height: 8),
          _infoRow(Icons.tag, 'UPI Ref', upiRef),
        ],
        if (discount > 0) ...[
          const SizedBox(height: 8),
          _infoRow(Icons.local_offer_outlined,
              couponCode.isNotEmpty ? 'Coupon ($couponCode)' : 'Discount',
              '-₹${_fmt(discount)}',
              valueColor: Colors.green[700]),
        ],
        if (delivery > 0) ...[
          const SizedBox(height: 8),
          _infoRow(Icons.local_shipping_outlined, 'Delivery Charges',
              '₹${_fmt(delivery)}',
              valueColor: Colors.grey[700]),
        ],
        if (pending > 0) ...[
          const SizedBox(height: 8),
          _infoRow(Icons.warning_amber_outlined, 'Pending',
              '₹${_fmt(pending)}',
              valueColor: Colors.red),
        ],
        const Divider(height: 20),
        Row(children: [
          const Text('Total Amount',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('₹${_fmt(grandTotal)}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue)),
        ]),
      ]),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> info) {
    final name  =
    '${info['firstname'] ?? ''} ${info['lastname'] ?? ''}'.trim();
    final email = info['email']?.toString()     ?? '';
    final phone = info['telephone']?.toString() ?? '';

    return _card(
      title: 'Customer Info',
      icon: Icons.person_outline,
      child: Column(children: [
        if (name.isNotEmpty)
          _infoRow(Icons.person_outline, 'Name', name),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 8),
          _infoRow(Icons.email_outlined, 'Email', email),
        ],
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 8),
          _infoRow(Icons.phone_outlined, 'Phone', '+91 $phone'),
        ],
      ]),
    );
  }

  Widget _buildHistoryCard(List<Map<String, dynamic>> history) {
    return _card(
      title: 'Order Timeline',
      icon: Icons.history,
      child: Column(
        children: history.asMap().entries.map((entry) {
          final i      = entry.key;
          final h      = entry.value;
          final isLast = i == history.length - 1;
          final status  = h['status_name'] ?? '';
          final comment = h['comment']?.toString() ?? '';
          final date    = h['date_added']?.toString() ?? '';

          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == 0 ? _statusColor(status) : Colors.grey[400],
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 44, color: Colors.grey[300]),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statusChip(status, small: true),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(comment,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                      const SizedBox(height: 2),
                      Text(_formatDate(date),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ]),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  // ── Shared widget helpers ─────────────────────────────────────────────────────

  Widget _card(
      {required String title,
        required IconData icon,
        required Widget child}) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 6)
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primaryOrange),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87)),
        ),
      ]);

  Widget _billRow(String label, double amount, {Color? color}) =>
      Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: color ?? Colors.black87))),
        Text(
          '${amount < 0 ? '-' : ''}₹${_fmt(amount.abs())}',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color ?? Colors.black87),
        ),
      ]);

  Widget _statusChip(String status, {bool small = false}) {
    final color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text,
        style: TextStyle(fontSize: 11, color: Colors.grey[700])),
  );

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'complete':
      case 'completed':
        return Colors.green;
      case 'canceled':
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      default:
        return AppColors.primaryBlue;
    }
  }

  String _fmt(double v) => v
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},');

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final h    = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m    = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${months[dt.month]} ${dt.year}, $h:$m $ampm';
    } catch (_) {
      return raw;
    }
  }
}