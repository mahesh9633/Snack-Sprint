import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';

import '../config/app_color.dart';
import '../model/address_model.dart';
import '../model/cart_model.dart';
import '../services/api_config_service.dart';
import '../services/apply_coupon_service.dart';
import '../services/order_api_service.dart';
import '../services/session_manager.dart';
import '../services/store_upi_service.dart';
import 'home_screen.dart';


class PaymentMethodScreen extends StatefulWidget {
  final AddressModel? selectedAddress;
  final double deliveryFee;
  final double finalTotal;

  const PaymentMethodScreen({
    super.key,
    this.selectedAddress,
    this.deliveryFee = 0,
    this.finalTotal = 0,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String        _selectedPayment = 'cod';
  AddressModel? _defaultAddress;
  final TextEditingController _couponController = TextEditingController();
  bool   _couponApplied  = false;
  bool   _couponLoading  = false;
  bool _placingOrder = false;
  bool _addrLoading = false;
  late double   _deliveryFee;
  late double   _finalTotal;
  String _couponCode     = '';
  String _couponError    = '';
  double _couponDiscount = 0.0;

  // ── UPI proof state ───────────────────────────────────────────────────────
  final TextEditingController _utrController = TextEditingController();
  XFile?  _paymentScreenshot;
  String  _utrError          = '';
  // ── Store / UPI state ─────────────────────────────────────────────────────
  StoreModel? _store;
  bool        _storeLoading = false;
  String      _storeError   = '';


  @override
  void initState() {
    super.initState();
    _defaultAddress = widget.selectedAddress;
    _deliveryFee    = widget.deliveryFee;
    _finalTotal = widget.finalTotal;
  }

  Future<void> _loadStore() async {
    setState(() { _storeLoading = true; _storeError = ''; });
    final token = await SessionManager.getToken() ?? '';
    final result = await StoreUpiService.getStoreUpi(token: token);
    if (!mounted) return;
    setState(() {
      _storeLoading = false;
      if (result.success && result.store != null) {
        _store = result.store;
      } else {
        _storeError = result.error.isNotEmpty
            ? result.error
            : 'Could not load UPI details';
      }
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    _utrController.dispose();
    super.dispose();
  }


  // ── Payment helpers ───────────────────────────────────────────────────────
  String get _paymentLabel => const {
    'cod': 'Cash on Delivery',
    'upi': 'UPI',
  }[_selectedPayment] ?? 'Cash on Delivery';

  String get _paymentApiValue => const {
    'cod': 'COD',
    'upi': 'UPI',
  }[_selectedPayment] ?? 'COD';

  // ── Place order enabled? ──────────────────────────────────────────────────
  bool get _isPlaceOrderEnabled {
    if (_selectedPayment == 'upi') {
      final utr        = _utrController.text.trim();
      final isValidUtr = RegExp(r'^\d{12}$').hasMatch(utr);
      return isValidUtr && _paymentScreenshot != null;
    }
    return true;
  }

  // ── Apply coupon ──────────────────────────────────────────────────────────
  Future<void> _applyCoupon(double cartTotal) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() => _couponError = 'Please enter a coupon code');
      return;
    }
    setState(() { _couponLoading = true; _couponError = ''; });

    final token  = await SessionManager.getToken() ?? '';
    final result = await CouponApiService.applyCoupon(
      token:      token,
      couponCode: code,
      grandTotal: cartTotal,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() { _couponError = result.error; _couponLoading = false; });
      return;
    }

    final coupon   = result.coupon!;
    final discount = coupon.computeDiscount(cartTotal);
    _applySuccess(coupon.code, discount);
  }

  void _applySuccess(String code, double discount) {
    setState(() {
      _couponApplied  = true;
      _couponCode     = code;
      _couponDiscount = double.parse(discount.toStringAsFixed(0));
      _couponLoading  = false;
      _couponError    = '';
    });
  }

  void _removeCoupon() {
    setState(() {
      _couponApplied  = false;
      _couponCode     = '';
      _couponDiscount = 0.0;
      _couponError    = '';
      _couponController.clear();
    });
  }

  // ── Pick screenshot ───────────────────────────────────────────────────────
  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _paymentScreenshot = picked);
  }

  // ── Open all coupons ──────────────────────────────────────────────────────
  Future<void> _openAllCoupons(double cartTotal) async {
    setState(() => _couponLoading = true);

    final token  = await SessionManager.getToken() ?? '';
    final result = await CouponApiService.getCoupons(token: token);

    setState(() => _couponLoading = false);
    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message.isNotEmpty ? result.message : 'Could not load coupons'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final selected = await Navigator.push<CouponModel>(
      context,
      MaterialPageRoute(builder: (_) => _AllCouponsScreen(
        coupons:   result.coupons,
        cartTotal: cartTotal,
      )),
    );

    if (selected != null) {
      _couponController.text = selected.code;
      _applySuccess(selected.code, selected.computeDiscount(cartTotal));
    }
  }

  // ── Place order ───────────────────────────────────────────────────────────
  Future<void> _placeOrder(BuildContext context, CartModel cart) async {
    if (_defaultAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a delivery address first'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // ── Confirmation dialog ───────────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shopping_bag_outlined, color: AppColors.buttonPrimary, size: 24),
            SizedBox(width: 10),
            Text('Confirm Order',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to place this order?',
                style: TextStyle(fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.buttonPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.buttonPrimary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Payment',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      Text(_paymentLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deliver to',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      Flexible(
                        child: Text(
                          _defaultAddress?.fullName ?? '',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('CANCEL',
                style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('CONFIRM',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // user tapped Cancel or dismissed
    setState(() => _placingOrder = true);
    try {
      String? screenshotBase64;
      if (_selectedPayment == 'upi' && _paymentScreenshot != null) {
        final bytes = await File(_paymentScreenshot!.path).readAsBytes();
        screenshotBase64 = base64Encode(bytes);
      }

      final result = await OrderApiService.placeOrder(
        cart:             cart,
        address:          _defaultAddress!,
        paymentMethod:    _paymentApiValue,
        couponCode:       _couponApplied ? _couponCode     : '',
        couponDiscount:   _couponApplied ? _couponDiscount : 0.0,
        deliveryCharge:   _deliveryFee,
        screenshotBase64: screenshotBase64,
        utrNumber:        _selectedPayment == 'upi' ? _utrController.text.trim() : '',
      );

      if (!mounted) return;
      setState(() => _placingOrder = false);

      final isSuccess = result['status']?.toString().toLowerCase() == 'success';
      final orderId   = result['order_id']?.toString() ?? '';

      if (isSuccess) {
        final purchasedItems = cart.items.values.toList();
        final cartSubTotal   = cart.totalPrice;
        final baseTotal      = cartSubTotal + _deliveryFee;
        final total          = baseTotal - _couponDiscount;
        cart.clearCart();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (nc) => _OrderSuccessScreen(
              orderId:        orderId,
              total:          total,
              paymentLabel:   _paymentLabel,
              address:        _defaultAddress!,
              purchasedItems: purchasedItems,
              deliveryFee:    _deliveryFee,
              // subTotal:       cart.totalPrice,
              subTotal:       cartSubTotal,
              onContinue: () async {
                final token      = await SessionManager.getToken()      ?? '';
                final customerId = await SessionManager.getCustomerId() ?? '';
                final telephone  = await SessionManager.getTelephone()  ?? '';
                if (!nc.mounted) return;
                Navigator.of(nc).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(
                      authToken:  token,
                      customerId: customerId,
                      telephone:  telephone,
                    ),
                  ),
                      (route) => false,
                );
              },
            ),
          ),
              (route) => false,
        );
      } else {
        _showErrorDialog(context,
            result['message']?.toString() ?? 'Order could not be placed. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _placingOrder = false);
      _showErrorDialog(context, 'Network error: $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Method',
          style: TextStyle(color: AppColors.appBarText, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<CartModel>(
        builder: (context, cart, _) {
          final baseTotal = cart.totalPrice + _deliveryFee;
          final grandTotal = baseTotal - _couponDiscount;
          return Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Delivery address ──────────────────────────────────
                    if (_addrLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: LinearProgressIndicator(color:AppColors.floatingCartBg),
                      )
                    else if (_defaultAddress != null) ...[
                      const Text('Delivery Address',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FFF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on,
                                  color: Color(0xFF2E7D32), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(
                                      _defaultAddress!.fullName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('Delivering here',
                                          style: TextStyle(fontSize: 9,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ]),
                                  const SizedBox(height: 5),
                                  Text(
                                    _defaultAddress!.singleLine,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        height: 1.4),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Icon(Icons.phone_outlined,
                                        size: 13, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(_defaultAddress!.phone,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600])),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Row(children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange[700]),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'No delivery address selected. Please go back and select an address.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Payment methods ───────────────────────────────────
                    const Text('Select Payment Method',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _paymentOption('cod', 'Cash on Delivery (COD)',
                        'Pay when you receive the order'),
                    const Divider(),
                    _paymentOption(
                        'upi', 'UPI', 'Google Pay, PhonePe, Paytm & more'),

                    // ── UPI section ───────────────────────────────────────
                    if (_selectedPayment == 'upi')
                      _buildUpiSection(grandTotal),

                    const SizedBox(height: 24),

                    // ── Coupons ───────────────────────────────────────────
                    _buildCouponSection(cart.totalPrice),

                    const SizedBox(height: 24),

                    // ── Order summary ─────────────────────────────────────
                    const Text('Order Summary',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(children: [
                        _summaryRow(
                            'Items', '${cart.items.length} product(s)'),
                        const SizedBox(height: 6),
                        _summaryRow('Sub Total',
                            '₹${cart.totalPrice.toStringAsFixed(0)}'),
                        const SizedBox(height: 6),
                        _summaryRow(
                            'Delivery',
                            _deliveryFee == 0 ? 'FREE' : '₹${_deliveryFee.toStringAsFixed(0)}',
                            valueColor: _deliveryFee == 0 ? Colors.green : Colors.black),
                        if (_couponApplied) ...[
                          const SizedBox(height: 6),
                          _summaryRow(
                              'Coupon ($_couponCode)',
                              '- ₹${_couponDiscount.toStringAsFixed(0)}',
                              valueColor: Colors.green),
                        ],
                        const Divider(height: 16),
                        _summaryRow(
                            'Grand Total',
                            '₹${grandTotal.toStringAsFixed(0)}',
                            bold: true),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cash on Delivery is available for this order',
                            style: TextStyle(
                                fontSize: 14, color: Colors.blue[900]),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom bar ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        '₹${grandTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_placingOrder || !_isPlaceOrderEnabled)
                          ? null
                          : () => _placeOrder(context, cart),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonPrimary,
                        disabledBackgroundColor: AppColors.buttonPrimaryDisabled,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _placingOrder
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                          : Text(
                        _selectedPayment == 'cod'
                            ? 'PLACE ORDER'
                            : 'PROCEED TO PAY',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _buildUpiSection(double grandTotal) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8, left: 8, right: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF0F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.buttonPrimary.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Step 1: Pay to merchant UPI ────────────────────────────
        _stepLabel('1', 'Pay to UPI ID'),
        const SizedBox(height: 10),

        if (_storeLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(color: AppColors.buttonPrimary),
          )
        else if (_storeError.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_storeError,
                    style: TextStyle(fontSize: 12, color: Colors.red[700])),
              ),
              TextButton(
                onPressed: _loadStore,
                child: const Text('Retry',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.buttonPrimary,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          )
        else if (_store != null) ...[
            // ── Merchant UPI card ───────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF8B4513).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B4513).withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B4513).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: AppColors.floatingCartBg, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_store!.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text(_store!.upiId,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.floatingCartBg,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: _store!.upiId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('UPI ID copied!'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: const Icon(Icons.copy,
                                size: 14, color: AppColors.buttonPrimary),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      '₹${grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20)),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 8),
            Text(
              'Open any UPI app, pay ₹${grandTotal.toStringAsFixed(0)} to the above UPI ID, then fill in the details below.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],

        const SizedBox(height: 16),
        const Divider(color: Color(0xFFEEEEEE)),
        const SizedBox(height: 12),

        // ── Step 2: Enter UTR + screenshot ─────────────────────────
        _stepLabel('2', 'Enter UTR & Attach Screenshot'),
        const SizedBox(height: 4),
        Text(
          'After paying, enter the 12-digit UTR/reference number and attach screenshot',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 10),

        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _utrController,
              keyboardType: TextInputType.number,
              maxLength: 12,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => _utrError = ''),
              decoration: InputDecoration(
                labelText: 'UTR / Reference Number',
                hintText: 'Enter 12-digit UTR',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.tag, size: 18,
                    color: AppColors.buttonPrimary),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.floatingCartBg, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _pickScreenshot,
            child: _paymentScreenshot == null
                ? DottedBorder(
              color: AppColors.floatingCartBg,
              strokeWidth: 1.5,
              dashPattern: const [6, 3],
              borderType: BorderType.RRect,
              radius: const Radius.circular(10),
              child: Container(
                width: 64,
                height: 56,
                alignment: Alignment.center,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.attach_file,
                          color:  AppColors.floatingCartBg, size: 20),
                      const SizedBox(height: 2),
                      Text('Attach',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500)),
                    ]),
              ),
            )
                : Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_paymentScreenshot!.path),
                  width: 64,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _paymentScreenshot = null),
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
            ]),
          ),
        ]),

        if (_utrError.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_utrError,
              style: const TextStyle(fontSize: 12, color: Colors.red)),
        ],

        const SizedBox(height: 10),

        // Checklist
        Row(children: [
          Flexible(
              child: _upiCheck(
                  RegExp(r'^\d{12}$')
                      .hasMatch(_utrController.text.trim()),
                  'UTR entered')),
          const SizedBox(width: 8),
          Flexible(
              child: _upiCheck(
                  _paymentScreenshot != null, 'Screenshot attached')),
        ]),
      ]),
    );
  }

  // ── Step label ────────────────────────────────────────────────────────────
  Widget _stepLabel(String number, String label) {
    return Row(children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.floatingCartBg,
          shape: BoxShape.circle,
        ),
        child: Text(number,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
  }

  // ── UPI check chip ────────────────────────────────────────────────────────
  Widget _upiCheck(bool done, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 14,
        color: done ? Colors.green : Colors.grey[400],
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: done ? Colors.green : Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ]);
  }

  // ── Coupon section ────────────────────────────────────────────────────────
  Widget _buildCouponSection(double cartTotal) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _couponApplied
              ? Colors.green.withOpacity(0.5)
              : Colors.grey[300]!,
          width: _couponApplied ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.floatingCartBg.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_offer_outlined,
                  color: AppColors.floatingCartBg, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Apply Coupon',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const Spacer(),
            if (_couponApplied)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('APPLIED',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              )
            else if (_couponLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,  color: AppColors.floatingCartBg),
              )
            else
              GestureDetector(
                onTap: () => _openAllCoupons(cartTotal),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('View all coupons',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.floatingCartBg.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16,  color: AppColors.floatingCartBg),
                  ),
                ]),
              ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: _couponApplied
              ? _buildAppliedCoupon()
              : _buildCouponInput(cartTotal),
        ),
      ]),
    );
  }

  Widget _buildCouponInput(double cartTotal) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: _couponController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2),
            decoration: InputDecoration(
              hintText: 'Enter coupon code',
              hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.normal,
                  letterSpacing: 0),
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.buttonPrimary, width: 1.5)),
            ),
            onChanged: (_) {
              if (_couponError.isNotEmpty) {
                setState(() => _couponError = '');
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed:
            _couponLoading ? null : () => _applyCoupon(cartTotal),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              disabledBackgroundColor: AppColors.buttonPrimaryDisabled,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: _couponLoading
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('APPLY',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
      ]),
      if (_couponError.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.error_outline, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Expanded(
              child: Text(_couponError,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.red))),
        ]),
      ],
    ]);
  }

  Widget _buildAppliedCoupon() {
    return Row(children: [
      const Icon(Icons.check_circle, color: Colors.green, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_couponCode,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 1)),
              const SizedBox(height: 2),
              Text('You save ₹${_couponDiscount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.green)),
            ]),
      ),
      GestureDetector(
        onTap: _removeCoupon,
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(8)),
          child: const Text('Remove',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  Widget _paymentOption(String value, String title, String subtitle) =>
      RadioListTile<String>(
        value: value,
        groupValue: _selectedPayment,

        onChanged: (v) {
          setState(() => _selectedPayment = v!);
          if (v == 'upi' && _store == null && !_storeLoading) {
            _loadStore();
          }
        },

        activeColor: AppColors.buttonPrimary,
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 14)),
      );

  Widget _summaryRow(String label, String value,
      {Color? valueColor, bool bold = false}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: bold ? Colors.black : Colors.grey[700],
                  fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                  bold ? FontWeight.bold : FontWeight.w500,
                  color: valueColor ??
                      (bold ? Colors.black : Colors.black87))),
        ],
      );

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 56),
          const SizedBox(height: 16),
          const Text('Order Failed',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style:
              TextStyle(fontSize: 14, color: Colors.grey[700])),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TRY AGAIN',
                style: TextStyle(
                    color: Color(0xFF8B4513),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AllCouponsScreen extends StatelessWidget {
  final List<CouponModel> coupons;
  final double            cartTotal;

  const _AllCouponsScreen({
    required this.coupons,
    required this.cartTotal,
  });

  @override
  Widget build(BuildContext context) {
    final eligible = coupons.where((c) => c.isEligible(cartTotal)).toList();
    final blocked  = coupons.where((c) => !c.isEligible(cartTotal)).toList();
    final sorted   = [...eligible, ...blocked];

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Available Coupons',
            style: TextStyle(
                color: AppColors.appBarText,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          color: Colors.white,
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Icon(Icons.shopping_cart_outlined,
                size: 16,  color: AppColors.floatingCartBg),
            const SizedBox(width: 8),
            Text('Your cart total: ',
                style:
                TextStyle(fontSize: 13, color: Colors.grey[600])),
            Text('₹${cartTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF000000))),
            const Spacer(),
            if (eligible.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('${eligible.length} applicable',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
        if (coupons.isEmpty)
          const Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_offer_outlined,
                    size: 52, color: Colors.grey),
                SizedBox(height: 14),
                Text('No coupons available',
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount:
              sorted.length + (blocked.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (blocked.isNotEmpty && index == eligible.length) {
                  return Padding(
                    padding:
                    const EdgeInsets.only(top: 8, bottom: 14),
                    child: Row(children: [
                      const Icon(Icons.lock_outline,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Not applicable for your cart',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Divider(color: Colors.grey[300])),
                    ]),
                  );
                }
                final i = (blocked.isNotEmpty && index > eligible.length)
                    ? index - 1
                    : index;
                final coupon = sorted[i];
                final isElg  = coupon.isEligible(cartTotal);
                final disc   = coupon.computeDiscount(cartTotal);

                return _CouponCard(
                  coupon:     coupon,
                  isEligible: isElg,
                  discount:   disc,
                  cartTotal:  cartTotal,
                  onTap:      isElg
                      ? () => Navigator.pop(context, coupon)
                      : null,
                );
              },
            ),
          ),
      ]),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final CouponModel   coupon;
  final bool          isEligible;
  final double        discount;
  final double        cartTotal;
  final VoidCallback? onTap;

  const _CouponCard({
    required this.coupon,
    required this.isEligible,
    required this.discount,
    required this.cartTotal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent =
    isEligible ?   AppColors.floatingCartBg : Colors.grey;

    return Opacity(
      opacity: isEligible ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isEligible ? Colors.white : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEligible
                ? accent.withOpacity(0.3)
                : Colors.grey[300]!,
            width: isEligible ? 1.5 : 1,
          ),
          boxShadow: isEligible
              ? [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]
              : [],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: accent.withOpacity(isEligible ? 0.05 : 0.03),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                  isEligible ? accent : Colors.grey[400],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(coupon.code,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(coupon.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isEligible
                              ? Colors.black87
                              : Colors.grey[500]))),
              if (isEligible)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                      'Save ₹${discount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coupon.description,
                      style: TextStyle(
                          fontSize: 13,
                          color: isEligible
                              ? Colors.grey[700]
                              : Colors.grey[400])),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _chip(
                        Icons.currency_rupee,
                        'Min ₹${coupon.minimumTotal.toStringAsFixed(0)}',
                        isEligible &&
                            cartTotal >= coupon.minimumTotal),
                    if (coupon.type == 'P' && coupon.total > 0)
                      _chip(
                          Icons.local_offer_outlined,
                          'Upto ₹${coupon.total.toStringAsFixed(0)} off',
                          isEligible),
                  ]),
                  if (!isEligible) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                        border:
                        Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 13, color: Colors.orange[700]),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                              cartTotal < coupon.minimumTotal
                                  ? 'Add ₹${(coupon.minimumTotal - cartTotal).toStringAsFixed(0)} more to unlock'
                                  : 'Not applicable for your cart total',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[800]),
                            )),
                      ]),
                    ),
                  ],
                  if (isEligible) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          // backgroundColor: const Color(0xFFFF0080),
                          backgroundColor: AppColors.buttonPrimary,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(
                            'Apply  •  Save ₹${discount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ),
                  ],
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, bool met) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: met
          ? Colors.green.withOpacity(0.08)
          : Colors.grey[100],
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
          color: met
              ? Colors.green.withOpacity(0.3)
              : Colors.grey[300]!),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
          met ? Icons.check_circle_outline : icon,
          size: 12,
          color: met ? Colors.green : Colors.grey[500]),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: met ? Colors.green : Colors.grey[500],
              fontWeight: FontWeight.w500)),
    ]),
  );
}

class _OrderSuccessScreen extends StatelessWidget {
  final String         orderId;
  final double         total;
  final String         paymentLabel;
  final AddressModel   address;
  final List<CartItem> purchasedItems;
  final VoidCallback   onContinue;
  final double         deliveryFee;
  final double         subTotal;

  const _OrderSuccessScreen({
    required this.orderId,
    required this.total,
    required this.paymentLabel,
    required this.address,
    required this.purchasedItems,
    required this.onContinue,
    required this.deliveryFee,
    required this.subTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle,
                      color: Color(0xFF4CAF50), size: 80),
                ),
                const SizedBox(height: 20),
                const Text('Order Placed\nSuccessfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.3)),
                const SizedBox(height: 16),
                if (orderId.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B4513).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color:
                          const Color(0xFF8B4513).withOpacity(0.4),
                          width: 1.2),
                    ),
                    child: Text('Order ID: #$orderId',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000000))),
                  ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text('Total Amount',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500])),
                                      const SizedBox(height: 3),
                                      Text(
                                          '₹${total.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF000000))),
                                    ]),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color:  AppColors.floatingCartBg
                                        .withOpacity(0.08),
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppColors.floatingCartBg
                                            .withOpacity(0.2)),
                                  ),
                                  child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                      children: [
                                        Text('Payment',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500])),
                                        const SizedBox(height: 3),
                                        Row(children: [
                                          const Icon(
                                              Icons.payments_outlined,
                                              size: 14,
                                              color: AppColors.floatingCartBg),
                                          const SizedBox(width: 4),
                                          Text(paymentLabel,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  color: AppColors.floatingCartBg)),
                                        ]),
                                      ]),
                                ),
                              ]),
                        ),
                        _div(),
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(20, 14, 20, 10),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: AppColors.floatingCartBg
                                      .withOpacity(0.1),
                                  borderRadius:
                                  BorderRadius.circular(8)),
                              child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 16,
                                  color: AppColors.floatingCartBg),
                            ),
                            const SizedBox(width: 10),
                            Text(
                                'Items Purchased  (${purchasedItems.length})',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                          ]),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: purchasedItems.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1,
                              indent: 72,
                              color: Colors.grey[100]),
                          itemBuilder: (_, i) =>
                              _ItemRow(item: purchasedItems[i]),
                        ),
                        Container(
                          margin:
                          const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${purchasedItems.fold(0, (s, i) => s + i.quantity)} item(s)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                Text('₹${subTotal.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                            if (subTotal + deliveryFee > total) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(children: [
                                    Icon(Icons.local_offer_outlined, size: 13, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text('Coupon Discount',
                                        style: TextStyle(fontSize: 12, color: Colors.green)),
                                  ]),
                                  Text(
                                    '- ₹${(subTotal + deliveryFee - total).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  Icon(Icons.local_shipping_outlined,
                                      size: 13, color: deliveryFee > 0 ? Colors.grey[600] : Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    deliveryFee > 0 ? 'Delivery' : 'Free Delivery',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: deliveryFee > 0 ? Colors.grey[600] : Colors.green),
                                  ),
                                ]),
                                Text(
                                  deliveryFee > 0 ? '₹${deliveryFee.toStringAsFixed(0)}' : 'FREE',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: deliveryFee > 0 ? Colors.grey[600] : Colors.green),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text('₹${total.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1B5E20))),
                              ],
                            ),
                          ]),
                        ),
                        _div(top: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              20, 14, 20, 20),
                          child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF0C831F)
                                            .withOpacity(0.1),
                                        borderRadius:
                                        BorderRadius.circular(8)),
                                    child: const Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: Color(0xFF0C831F)),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Delivering to',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87)),
                                ]),
                                const SizedBox(height: 12),
                                Text(address.fullName,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(address.singleLine,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600])),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Icon(Icons.phone_outlined,
                                      size: 14,
                                      color: Colors.grey[500]),
                                  const SizedBox(width: 5),
                                  Text(address.phone,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600])),
                                ]),
                              ]),
                        ),
                      ]),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C831F).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                        const Color(0xFF0C831F).withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_shipping_outlined,
                        color: Color(0xFF0C831F), size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estimated Delivery',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0C831F))),
                            const SizedBox(height: 2),
                            Text(
                                'Your order will be delivered soon!',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600])),
                          ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('CONTINUE SHOPPING',
                    style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _div({double top = 0}) => Container(
      margin: EdgeInsets.only(top: top),
      height: 1,
      color: Colors.grey[100]);
}

// ── Item Row ──────────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final CartItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final p     = item.product;
    final total = p.price * item.quantity;
    final base  = ApiConfig.imageBase;
    String imgUrl = '';
    if (p.imageUrl.isNotEmpty && p.imageUrl != 'no_image.png') {
      imgUrl = p.imageUrl.startsWith('http')
          ? p.imageUrl
          : '$base${p.imageUrl}';
    } else if (p.image.isNotEmpty && p.image != 'no_image.png') {
      imgUrl = p.image.startsWith('http')
          ? p.image
          : '$base${p.image}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 52,
            height: 52,
            color: const Color(0xFFF5F5F5),
            child: imgUrl.isNotEmpty
                ? Image.network(imgUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ph())
                : _ph(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5D8),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.floatingCartBg
                              .withOpacity(0.3)),
                    ),
                    child: Text('Qty: ${item.quantity}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.floatingCartBg,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (p.weight.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        p.weight,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ]),
              ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${total.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20))),
          const SizedBox(height: 2),
          Text('₹${p.price.toStringAsFixed(0)} each',
              style:
              TextStyle(fontSize: 10, color: Colors.grey[400])),
        ]),
      ]),
    );
  }

  Widget _ph() => const Center(
      child: Icon(Icons.image_not_supported,
          color: Colors.grey, size: 20));
}