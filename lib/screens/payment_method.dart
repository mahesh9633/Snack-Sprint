// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
//
// import 'package:image_picker/image_picker.dart';
// import 'package:dotted_border/dotted_border.dart';
// import 'dart:io';
// import 'dart:convert';
// import 'package:provider/provider.dart';
//
// import '../config/app_color.dart';
// import '../model/address_model.dart';
// import '../model/cart_model.dart';
// import '../services/Upi qr service.dart';
// import '../services/api_config_service.dart';
// import '../services/apply_coupon_service.dart';
// import '../services/get_profile_service.dart';
// import '../services/order_api_service.dart';
// import '../services/session_manager.dart';
// import '../services/store_profile_cache.dart';
//
// import 'home_screen.dart';
//
//
// class PaymentMethodScreen extends StatefulWidget {
//   final AddressModel? selectedAddress;
//   final double deliveryFee;
//   final double finalTotal;
//
//   const PaymentMethodScreen({
//     super.key,
//     this.selectedAddress,
//     this.deliveryFee = 0,
//     this.finalTotal = 0,
//   });
//
//   @override
//   State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
// }
//
// class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
//   String        _selectedPayment = '';
//   AddressModel? _defaultAddress;
//   final TextEditingController _couponController = TextEditingController();
//   bool   _couponApplied  = false;
//   bool   _couponLoading  = false;
//   bool _placingOrder = false;
//   bool _addrLoading = false;
//   late double   _deliveryFee;
//   late double   _finalTotal;
//   String _couponCode     = '';
//   String _couponError    = '';
//   double _couponDiscount = 0.0;
//
//   // ── UPI proof state ───────────────────────────────────────────────────────
//   XFile?  _paymentScreenshot;
//
//   // ── Customer phone (auto-filled, replaces manual UTR entry) ──────────────
//   String  _customerPhone = '';
//   bool    _phoneLoading  = false;
//
//   // ── QR state ───────────────────────────────────────────────────────────────
//   String  _qrImageUrl = '';
//   bool    _qrLoading  = false;
//   String  _qrError    = '';
//
//   // ── Wallet ─────────────────────────────────────────────────────────────
//   double _walletBalance = 0;
//   bool   _useWallet     = false;
//
//   // ── Store's enabled payment methods — read instantly from the cache
//   // that was already preloaded at splash, no network call, no spinner ──────
//   List<Map<String, dynamic>> _paymentMethods = StoreProfileCache.paymentMethods;
//
//   // Silently re-checks for admin changes (e.g. COD disabled) while this
//   // screen stays open, so it stays live even without leaving/returning.
//   Timer? _paymentMethodsPollTimer;
//
//
//   @override
//   void initState() {
//     super.initState();
//     _defaultAddress = widget.selectedAddress;
//     _deliveryFee    = widget.deliveryFee;
//     _finalTotal = widget.finalTotal;
//
//     // Default-select the first enabled payment method (instant, from cache).
//     if (_paymentMethods.isNotEmpty) {
//       _selectedPayment = _paymentMethods.first['name'].toString();
//     }
//
//     // If the default selection is already UPI, fetch the QR right away —
//     // otherwise the UPI section shows with no QR until the user re-taps it.
//     if (_isUpiFlow) {
//       final amount = (_cartGrandTotalFallback > 0)
//           ? _cartGrandTotalFallback
//           : widget.finalTotal;
//       _loadQrCode(amount);
//     }
//
//     _loadCustomerPhone();
//
//     // Always refresh payment methods from the backend when this screen
//     // opens, so admin changes (e.g. disabling COD) show up immediately
//     // instead of relying on the stale splash-time cache.
//     _refreshPaymentMethods();
//
//     // Keep checking silently while the customer stays on this screen,
//     // so a mid-visit admin change (e.g. disabling COD) also updates live.
//     _paymentMethodsPollTimer = Timer.periodic(
//       const Duration(seconds: 6),
//           (_) => _refreshPaymentMethods(),
//     );
//   }
//
//   // ── Refresh payment methods (bypasses stale cache) ────────────────────────
//   Future<void> _refreshPaymentMethods() async {
//     await StoreProfileCache.preload(forceRefresh: true);
//     if (!mounted) return;
//
//     final fresh = StoreProfileCache.paymentMethods;
//
//     // Skip a no-op setState if nothing actually changed (avoids unnecessary
//     // rebuilds every 15s when the list is unchanged).
//     final unchanged = fresh.length == _paymentMethods.length &&
//         fresh.every((m) => _paymentMethods.any(
//               (existing) => existing['name'].toString() == m['name'].toString(),
//         ));
//     if (unchanged) return;
//
//     setState(() {
//       _paymentMethods = fresh;
//
//       // If the previously selected method was disabled by the admin,
//       // fall back to the first still-enabled method (or none).
//       final stillValid = fresh.any((m) => m['name'].toString() == _selectedPayment);
//       if (!stillValid) {
//         _selectedPayment = fresh.isNotEmpty ? fresh.first['name'].toString() : '';
//         _qrImageUrl = '';
//         _qrError = '';
//
//         // If we just auto-switched into the UPI flow, kick off the QR
//         // fetch automatically (mirrors what the manual tap would do).
//         if (_isUpiFlow && _qrImageUrl.isEmpty && !_qrLoading) {
//           final amount = (_cartGrandTotalFallback > 0)
//               ? _cartGrandTotalFallback
//               : widget.finalTotal;
//           _loadQrCode(amount);
//         }
//       }
//     });
//   }
//
//   Future<void> _loadCustomerPhone() async {
//     setState(() => _phoneLoading = true);
//     try {
//       final result = await ProfileGetApiService.getProfile();
//       if (result['success'] == true) {
//         final data      = result['data'] as Map<String, dynamic>;
//         final upiNumber = data['upi_number'] as String? ?? '';
//         final wallet    = double.tryParse(data['wallet_amount'].toString()) ?? 0;
//         if (mounted) {
//           setState(() {
//             _customerPhone  = upiNumber;
//             _walletBalance  = wallet;
//             _phoneLoading   = false;
//           });
//         }
//       } else if (mounted) {
//         setState(() => _phoneLoading = false);
//       }
//     } catch (_) {
//       if (mounted) setState(() => _phoneLoading = false);
//     }
//   }
//
//   Future<void> _loadQrCode(double amount) async {
//     setState(() { _qrLoading = true; _qrError = ''; });
//     final token  = await SessionManager.getToken() ?? '';
//     final result = await UpiQrService.generateQr(token: token, amount: amount);
//     if (!mounted) return;
//     setState(() {
//       _qrLoading = false;
//       if (result.success && result.qrImageUrl.isNotEmpty) {
//         _qrImageUrl = result.qrImageUrl;
//       } else {
//         _qrError = result.error.isNotEmpty
//             ? result.error
//             : 'Could not generate QR code';
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _paymentMethodsPollTimer?.cancel();
//     _couponController.dispose();
//     super.dispose();
//   }
//
//
//   // ── Payment helpers ───────────────────────────────────────────────────────
//   // _selectedPayment now stores the actual payment method NAME as returned
//   // by the backend (e.g. "Cash on Delivery", "UPI"), not a fixed key.
//   String get _paymentLabel => _selectedPayment;
//
//   // Treat any method whose name contains "UPI" as the UPI flow (shows the
//   // QR/screenshot section); everything else behaves like COD.
//   bool get _isUpiFlow => _selectedPayment.toUpperCase().contains('UPI');
//
//   String get _paymentApiValue => _selectedPayment; // send the method name as-is
//
//   // ── Place order enabled? ──────────────────────────────────────────────────
//   bool get _isPlaceOrderEnabled {
//     if (_paymentMethods.isEmpty) return false;
//     if (_isUpiFlow) {
//       return _customerPhone.isNotEmpty && _paymentScreenshot != null;
//     }
//     return true;
//   }
//
//   // ── Apply coupon ──────────────────────────────────────────────────────────
//   Future<void> _applyCoupon(double cartTotal) async {
//     final code = _couponController.text.trim();
//     if (code.isEmpty) {
//       setState(() => _couponError = 'Please enter a coupon code');
//       return;
//     }
//     setState(() { _couponLoading = true; _couponError = ''; });
//
//     final token  = await SessionManager.getToken() ?? '';
//     final result = await CouponApiService.applyCoupon(
//       token:      token,
//       couponCode: code,
//       grandTotal: cartTotal,
//     );
//
//     if (!mounted) return;
//
//     if (!result.success) {
//       setState(() { _couponError = result.error; _couponLoading = false; });
//       return;
//     }
//
//     final coupon = result.coupon!;
//     // Trust the backend's own discount_amount — it already applied the
//     // percentage/flat cap and any business rules, don't recompute client-side.
//     _applySuccess(coupon.code, coupon.discountAmount);
//   }
//
//   void _applySuccess(String code, double discount) {
//     setState(() {
//       _couponApplied  = true;
//       _couponCode     = code;
//       _couponDiscount = double.parse(discount.toStringAsFixed(0));
//       _couponLoading  = false;
//       _couponError    = '';
//     });
//   }
//
//   void _removeCoupon() {
//     setState(() {
//       _couponApplied  = false;
//       _couponCode     = '';
//       _couponDiscount = 0.0;
//       _couponError    = '';
//       _couponController.clear();
//     });
//   }
//
//   // ── Pick screenshot ───────────────────────────────────────────────────────
// // NEW
//   Future<void> _pickScreenshot() async {
//     final source = await showModalBottomSheet<ImageSource>(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (ctx) => SafeArea(
//         child: Wrap(
//           children: [
//             ListTile(
//               leading: const Icon(Icons.photo_library_outlined, color: AppColors.buttonPrimary),
//               title: const Text('Choose from Gallery'),
//               onTap: () => Navigator.pop(ctx, ImageSource.gallery),
//             ),
//             ListTile(
//               leading: const Icon(Icons.camera_alt_outlined, color: AppColors.buttonPrimary),
//               title: const Text('Take a Photo'),
//               onTap: () => Navigator.pop(ctx, ImageSource.camera),
//             ),
//           ],
//         ),
//       ),
//     );
//
//     if (source == null) return;
//
//     final picker = ImagePicker();
//     final XFile? picked = await picker.pickImage(source: source, imageQuality: 85);
//     if (picked != null) setState(() => _paymentScreenshot = picked);
//   }
//
//   // ── Open all coupons ──────────────────────────────────────────────────────
//   Future<void> _openAllCoupons(double cartTotal) async {
//     setState(() => _couponLoading = true);
//
//     final token  = await SessionManager.getToken() ?? '';
//     final result = await CouponApiService.getCoupons(token: token);
//
//     setState(() => _couponLoading = false);
//     if (!mounted) return;
//
//     if (!result.success) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text(result.message.isNotEmpty ? result.message : 'Could not load coupons'),
//         backgroundColor: Colors.red,
//       ));
//       return;
//     }
//
//     // _AllCouponsScreen now calls the applyCoupon API itself when the user
//     // taps a card, and only pops once the backend confirms success — so
//     // `selected` here is already backend-validated with a real discountAmount.
//     final selected = await Navigator.push<CouponModel>(
//       context,
//       MaterialPageRoute(builder: (_) => _AllCouponsScreen(
//         coupons:   result.coupons,
//         cartTotal: cartTotal,
//         token:     token,
//       )),
//     );
//
//     if (selected != null) {
//       _couponController.text = selected.code;
//       _applySuccess(selected.code, selected.discountAmount);
//     }
//   }
//
//   // ── Wallet math ────────────────────────────────────────────────────────
//   double _walletApplied(double grandTotal) =>
//       _useWallet ? (_walletBalance < grandTotal ? _walletBalance : grandTotal) : 0;
//
//   double _payableAmount(double grandTotal) =>
//       grandTotal - _walletApplied(grandTotal);
//
//   // ── Place order ───────────────────────────────────────────────────────────
//   Future<void> _placeOrder(BuildContext context, CartModel cart) async {
//     if (_defaultAddress == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//         content: Text('Please select a delivery address first'),
//         backgroundColor: Colors.red,
//       ));
//       return;
//     }
//
//     // Re-validate the selected payment method is still enabled by the
//     // store right before ordering (admin may have disabled it meanwhile).
//     final stillEnabled = _paymentMethods.any(
//           (m) => m['name'].toString() == _selectedPayment,
//     );
//     if (!stillEnabled) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//         content: Text('This payment method is no longer available. Please choose another.'),
//         backgroundColor: Colors.red,
//       ));
//       await _refreshPaymentMethods();
//       return;
//     }
//
//     // ── Confirmation dialog ───────────────────────────────────────────────
//     final confirmed = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Row(
//           children: [
//             Icon(Icons.shopping_bag_outlined, color: AppColors.buttonPrimary, size: 24),
//             SizedBox(width: 10),
//             Text('Confirm Order',
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Are you sure you want to place this order?',
//                 style: TextStyle(fontSize: 14, color: Colors.black87)),
//             const SizedBox(height: 12),
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: AppColors.buttonPrimary.withOpacity(0.05),
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(
//                     color: AppColors.buttonPrimary.withOpacity(0.2)),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text('Payment',
//                           style: TextStyle(
//                               fontSize: 12, color: Colors.grey[600])),
//                       Text(_paymentLabel,
//                           style: const TextStyle(
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.black87)),
//                     ],
//                   ),
//                   const SizedBox(height: 6),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text('Deliver to',
//                           style: TextStyle(
//                               fontSize: 12, color: Colors.grey[600])),
//                       Flexible(
//                         child: Text(
//                           _defaultAddress?.fullName ?? '',
//                           textAlign: TextAlign.right,
//                           style: const TextStyle(
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.black87),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           OutlinedButton(
//             onPressed: () => Navigator.pop(context, false),
//             style: OutlinedButton.styleFrom(
//               side: BorderSide(color: Colors.grey[400]!),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8)),
//               padding:
//               const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//             ),
//             child: const Text('CANCEL',
//                 style: TextStyle(
//                     color: Colors.black54,
//                     fontWeight: FontWeight.bold)),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.buttonPrimary,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8)),
//               padding:
//               const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//             ),
//             child: const Text('CONFIRM',
//                 style: TextStyle(
//                     color: Colors.white, fontWeight: FontWeight.bold)),
//           ),
//         ],
//       ),
//     );
//
//     if (confirmed != true) return; // user tapped Cancel or dismissed
//     setState(() => _placingOrder = true);
//     try {
//       String? screenshotBase64;
//       if (_isUpiFlow && _paymentScreenshot != null) {
//         final bytes = await File(_paymentScreenshot!.path).readAsBytes();
//         screenshotBase64 = base64Encode(bytes);
//       }
//
//       // Recompute the wallet amount to apply right before sending, using
//       // the freshest cart/coupon values (avoids using a stale grandTotal).
//       final cartSubTotalNow = cart.totalPrice;
//       final grandTotalNow   = cartSubTotalNow + _deliveryFee - _couponDiscount;
//       final walletUsedNow   = _walletApplied(grandTotalNow);
//
//       final result = await OrderApiService.placeOrder(
//         cart:             cart,
//         address:          _defaultAddress!,
//         paymentMethod:    _paymentApiValue,
//         couponCode:       _couponApplied ? _couponCode     : '',
//         couponDiscount:   _couponApplied ? _couponDiscount : 0.0,
//         deliveryCharge:   _deliveryFee,
//         screenshotBase64: screenshotBase64,
//         utrNumber:        _isUpiFlow ? _customerPhone : '',
//         walletAmountUsed: walletUsedNow,
//       );
//
//       if (!mounted) return;
//       setState(() => _placingOrder = false);
//
//       final isSuccess = result['status']?.toString().toLowerCase() == 'success';
//       final orderId   = result['order_id']?.toString() ?? '';
//
//       if (isSuccess) {
//         final purchasedItems = cart.items.values.toList();
//         final cartSubTotal   = cart.totalPrice;
//         final baseTotal      = cartSubTotal + _deliveryFee;
//         final total          = baseTotal - _couponDiscount - walletUsedNow;
//         cart.clearCart();
//
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(
//             builder: (nc) => _OrderSuccessScreen(
//               orderId:        orderId,
//               total:          total,
//               paymentLabel:   _paymentLabel,
//               address:        _defaultAddress!,
//               purchasedItems: purchasedItems,
//               deliveryFee:    _deliveryFee,
//               // subTotal:       cart.totalPrice,
//               subTotal:       cartSubTotal,
//               onContinue: () async {
//                 final token      = await SessionManager.getToken()      ?? '';
//                 final customerId = await SessionManager.getCustomerId() ?? '';
//                 final telephone  = await SessionManager.getTelephone()  ?? '';
//                 if (!nc.mounted) return;
//                 Navigator.of(nc).pushAndRemoveUntil(
//                   MaterialPageRoute(
//                     builder: (_) => HomeScreen(
//                       authToken:  token,
//                       customerId: customerId,
//                       telephone:  telephone,
//                     ),
//                   ),
//                       (route) => false,
//                 );
//               },
//             ),
//           ),
//               (route) => false,
//         );
//       } else {
//         _showToast(context,
//             _cleanMessage(result['message']?.toString() ?? 'Order could not be placed. Please try again.'));
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _placingOrder = false);
//       _showToast(context, 'Network error. Please try again.');
//     }
//   }
//
//   // ── Build ─────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     // Cap content width on large screens (tablets / web / desktop) while
//     // staying fully fluid on phones of any size.
//     final maxContentWidth = screenWidth > 900
//         ? 720.0
//         : screenWidth > 600
//         ? 560.0
//         : double.infinity;
//     final horizontalPad = screenWidth > 600 ? 32.0 : 24.0;
//
//     return Scaffold(
//       backgroundColor: AppColors.white,
//       appBar: AppBar(
//         backgroundColor: AppColors.appBarBg,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'Payment Method',
//           style: TextStyle(color: AppColors.appBarText, fontWeight: FontWeight.bold),
//         ),
//       ),
//       body: Consumer<CartModel>(
//         builder: (context, cart, _) {
//           final baseTotal = cart.totalPrice + _deliveryFee;
//           final grandTotal = baseTotal - _couponDiscount;
//
//           // Auto-disable wallet if it no longer fully covers the total
//           // (e.g. user added more items after enabling it).
//           if (_useWallet && _walletBalance < grandTotal) {
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               if (mounted) setState(() => _useWallet = false);
//             });
//           }
//
//           return Column(children: [
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Center(
//                   child: ConstrainedBox(
//                     constraints: BoxConstraints(maxWidth: maxContentWidth),
//                     child: Padding(
//                       padding: EdgeInsets.symmetric(
//                           horizontal: horizontalPad, vertical: 24),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//
//                           // ── Delivery address ──────────────────────────────────
//                           if (_addrLoading)
//                             const Padding(
//                               padding: EdgeInsets.only(bottom: 24),
//                               child: LinearProgressIndicator(color:AppColors.floatingCartBg),
//                             )
//                           else if (_defaultAddress != null) ...[
//                             const Text('Delivery Address',
//                                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                             const SizedBox(height: 12),
//                             Container(
//                               padding: const EdgeInsets.all(16),
//                               decoration: BoxDecoration(
//                                 color: AppColors.successLight,
//                                 borderRadius: BorderRadius.circular(12),
//                                 border: Border.all(color: AppColors.success.withOpacity(0.2), width: 1.5),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.success.withOpacity(0.06),
//                                     blurRadius: 8,
//                                     offset: const Offset(0, 2),
//                                   ),
//                                 ],
//                               ),
//                               child: Row(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Container(
//                                     padding: const EdgeInsets.all(8),
//                                     decoration: BoxDecoration(
//                                       color: AppColors.success.withOpacity(0.12),
//                                       shape: BoxShape.circle,
//                                     ),
//                                     child: const Icon(Icons.location_on,
//                                         color: AppColors.success, size: 20),
//                                   ),
//                                   const SizedBox(width: 12),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment: CrossAxisAlignment.start,
//                                       children: [
//                                         Wrap(
//                                           crossAxisAlignment: WrapCrossAlignment.center,
//                                           spacing: 8,
//                                           runSpacing: 4,
//                                           children: [
//                                             Text(
//                                               _defaultAddress!.fullName,
//                                               style: const TextStyle(
//                                                 fontSize: 15,
//                                                 fontWeight: FontWeight.bold,
//                                                 color: AppColors.textDark,
//                                               ),
//                                             ),
//                                             Container(
//                                               padding: const EdgeInsets.symmetric(
//                                                   horizontal: 7, vertical: 2),
//                                               decoration: BoxDecoration(
//                                                 color: AppColors.success,
//                                                 borderRadius: BorderRadius.circular(10),
//                                               ),
//                                               child: const Text('Delivering here',
//                                                   style: TextStyle(fontSize: 9,
//                                                       color: Colors.white,
//                                                       fontWeight: FontWeight.bold)),
//                                             ),
//                                           ],
//                                         ),
//                                         const SizedBox(height: 5),
//                                         Text(
//                                           _defaultAddress!.singleLine,
//                                           style: TextStyle(
//                                               fontSize: 13,
//                                               color: Colors.grey[700],
//                                               height: 1.4),
//                                         ),
//                                         const SizedBox(height: 4),
//                                         Row(children: [
//                                           Icon(Icons.phone_outlined,
//                                               size: 13, color: Colors.grey[500]),
//                                           const SizedBox(width: 4),
//                                           Flexible(
//                                             child: Text(_defaultAddress!.phone,
//                                                 style: TextStyle(
//                                                     fontSize: 13,
//                                                     color: Colors.grey[600])),
//                                           ),
//                                         ]),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 24),
//                           ] else ...[
//                             Container(
//                               padding: const EdgeInsets.all(14),
//                               decoration: BoxDecoration(
//                                 color: Colors.orange[50],
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(color: Colors.orange[300]!),
//                               ),
//                               child: Row(children: [
//                                 Icon(Icons.warning_amber_rounded,
//                                     color: Colors.orange[700]),
//                                 const SizedBox(width: 10),
//                                 const Expanded(
//                                   child: Text(
//                                     'No delivery address selected. Please go back and select an address.',
//                                     style: TextStyle(fontSize: 13),
//                                   ),
//                                 ),
//                               ]),
//                             ),
//                             const SizedBox(height: 24),
//                           ],
//
//                           // ── Payment methods ───────────────────────────────────
//                           const Text('Select Payment Method',
//                               style: TextStyle(
//                                   fontSize: 18, fontWeight: FontWeight.bold)),
//                           const SizedBox(height: 16),
//
//                           if (_paymentMethods.isEmpty)
//                             Container(
//                               padding: const EdgeInsets.all(14),
//                               decoration: BoxDecoration(
//                                 color: Colors.orange[50],
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(color: Colors.orange[300]!),
//                               ),
//                               child: const Text(
//                                 'No payment methods are currently enabled by the store. Please contact the store.',
//                                 style: TextStyle(fontSize: 13),
//                               ),
//                             )
//                           else
//                             ...List.generate(_paymentMethods.length, (i) {
//                               final m = _paymentMethods[i];
//                               final name = m['name'].toString();
//                               final isUpi = name.toUpperCase().contains('UPI');
//                               return Column(children: [
//                                 _paymentOption(
//                                   name,
//                                   name,
//                                   isUpi
//                                       ? 'Google Pay, PhonePe, Paytm & more'
//                                       : 'Pay when you receive the order',
//                                 ),
//                                 if (i != _paymentMethods.length - 1) const Divider(),
//                               ]);
//                             }),
//
//                           // ── UPI section ───────────────────────────────────────
//                           if (_isUpiFlow)
//                             _buildUpiSection(grandTotal),
//
//                           const SizedBox(height: 24),
//
//                           // ── Wallet ─────────────────────────────────────────────
//                           if (_walletBalance > 0) ...[
//                             _buildWalletSection(grandTotal),
//                             const SizedBox(height: 24),
//                           ],
//
//                           // ── Coupons ───────────────────────────────────────────
//                           _buildCouponSection(cart.totalPrice),
//
//                           const SizedBox(height: 24),
//
//                           // ── Order summary ─────────────────────────────────────
//                           const Text('Order Summary',
//                               style: TextStyle(
//                                   fontSize: 16, fontWeight: FontWeight.bold)),
//                           const SizedBox(height: 12),
//                           Container(
//                             padding: const EdgeInsets.all(14),
//                             decoration: BoxDecoration(
//                               color: const Color(0xFFF8F8F8),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Column(children: [
//                               _summaryRow(
//                                   'Items', '${cart.items.length} product(s)'),
//                               const SizedBox(height: 6),
//                               _summaryRow('Sub Total',
//                                   '₹${cart.totalPrice.toStringAsFixed(0)}'),
//                               const SizedBox(height: 6),
//                               _summaryRow(
//                                   'Delivery',
//                                   _deliveryFee == 0 ? 'FREE' : '₹${_deliveryFee.toStringAsFixed(0)}',
//                                   valueColor: _deliveryFee == 0 ? AppColors.success : AppColors.textDark),
//                               if (_couponApplied) ...[
//                                 const SizedBox(height: 6),
//                                 _summaryRow(
//                                     'Coupon ($_couponCode)',
//                                     '- ₹${_couponDiscount.toStringAsFixed(0)}',
//                                     valueColor: AppColors.success),
//                               ],
//                               if (_useWallet && _walletApplied(grandTotal) > 0) ...[
//                                 const SizedBox(height: 6),
//                                 _summaryRow(
//                                     'Wallet Applied',
//                                     '- ₹${_walletApplied(grandTotal).toStringAsFixed(0)}',
//                                     valueColor: AppColors.success),
//                               ],
//                               const Divider(height: 16),
//                               _summaryRow(
//                                   'Payable Amount',
//                                   '₹${_payableAmount(grandTotal).toStringAsFixed(0)}',
//                                   bold: true),
//                             ]),
//                           ),
//                           const SizedBox(height: 24),
//                           Container(
//                             padding: const EdgeInsets.all(16),
//                             decoration: BoxDecoration(
//                               color: Colors.blue[50],
//                               borderRadius: BorderRadius.circular(8),
//                               border: Border.all(color: Colors.blue[200]!),
//                             ),
//                             child: Row(children: [
//                               Icon(Icons.info_outline,
//                                   color: Colors.blue[700], size: 20),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: Text(
//                                   'Cash on Delivery is available for this order',
//                                   style: TextStyle(
//                                       fontSize: 14, color: Colors.blue[900]),
//                                 ),
//                               ),
//                             ]),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//
//             // ── Bottom bar ────────────────────────────────────────────────
//             Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.1),
//                     blurRadius: 10,
//                     offset: const Offset(0, -2),
//                   ),
//                 ],
//               ),
//               child: SafeArea(
//                 child: Center(
//                   child: ConstrainedBox(
//                     constraints: BoxConstraints(maxWidth: maxContentWidth),
//                     child: Padding(
//                       padding: EdgeInsets.symmetric(
//                           horizontal: horizontalPad, vertical: 16),
//                       child: Column(children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text('Total Amount:',
//                                 style: TextStyle(
//                                     fontSize: 18, fontWeight: FontWeight.bold)),
//                             Text(
//                               '₹${_payableAmount(grandTotal).toStringAsFixed(0)}',
//                               style: const TextStyle(
//                                 fontSize: 22,
//                                 fontWeight: FontWeight.bold,
//                                 color: AppColors.textDark,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 12),
//                         SizedBox(
//                           width: double.infinity,
//                           child: ElevatedButton(
//                             onPressed: (_placingOrder || !_isPlaceOrderEnabled)
//                                 ? null
//                                 : () => _placeOrder(context, cart),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: AppColors.buttonPrimary,
//                               disabledBackgroundColor: AppColors.buttonPrimaryDisabled,
//                               padding: const EdgeInsets.symmetric(vertical: 16),
//                               shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12)),
//                             ),
//                             child: _placingOrder
//                                 ? const SizedBox(
//                               height: 22,
//                               width: 22,
//                               child: CircularProgressIndicator(
//                                   color: Colors.white, strokeWidth: 2.5),
//                             )
//                                 : Text(
//                               _isUpiFlow
//                                   ? 'PROCEED TO PAY'
//                                   : 'PLACE ORDER',
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ]),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ]);
//         },
//       ),
//     );
//   }
//
//   Widget _buildUpiSection(double grandTotal) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         // Decide layout based on the WIDTH AVAILABLE TO THIS SECTION
//         // (not the full screen) so it adapts inside any container/screen size.
//         final isNarrow = constraints.maxWidth < 360;
//         final qrSize = constraints.maxWidth < 340
//             ? constraints.maxWidth * 0.55
//             : (constraints.maxWidth < 500 ? 180.0 : 220.0);
//
//         return Container(
//           margin: const EdgeInsets.only(top: 4, bottom: 8),
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: AppColors.primaryBlue.withOpacity(0.05),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppColors.primaryBlue.withOpacity(0.25)),
//           ),
//           child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//
//             // ── Step 1: Scan QR to pay ─────────────────────────────────
//             _stepLabel('1', 'Scan QR to Pay'),
//             const SizedBox(height: 10),
//
//             if (_qrLoading)
//               const Padding(
//                 padding: EdgeInsets.symmetric(vertical: 8),
//                 child: LinearProgressIndicator(color: AppColors.buttonPrimary),
//               )
//             else if (_qrError.isNotEmpty)
//               Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Colors.red[50],
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.red[200]!),
//                 ),
//                 child: Row(children: [
//                   Icon(Icons.error_outline, size: 14, color: Colors.red[700]),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(_qrError,
//                         style: TextStyle(fontSize: 12, color: Colors.red[700])),
//                   ),
//                   TextButton(
//                     onPressed: () => _loadQrCode(grandTotal),
//                     child: const Text('Retry',
//                         style: TextStyle(
//                             fontSize: 12,
//                             color: AppColors.buttonPrimary,
//                             fontWeight: FontWeight.bold)),
//                   ),
//                 ]),
//               )
//             else if (_qrImageUrl.isNotEmpty)
//                 Center(
//                   child: Container(
//                     padding: const EdgeInsets.all(12),
//                     width: double.infinity,
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: AppColors.accentDark.withOpacity(0.3)),
//                       boxShadow: [
//                         BoxShadow(
//                           color: AppColors.accentDark.withOpacity(0.06),
//                           blurRadius: 8,
//                           offset: const Offset(0, 2),
//                         ),
//                       ],
//                     ),
//                     child: Column(children: [
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(8),
//                         child: Image.network(
//                           _qrImageUrl,
//                           width: qrSize,
//                           height: qrSize,
//                           fit: BoxFit.contain,
//                           loadingBuilder: (_, child, progress) {
//                             if (progress == null) return child;
//                             return SizedBox(
//                               width: qrSize,
//                               height: qrSize,
//                               child: const Center(
//                                   child: CircularProgressIndicator(
//                                       strokeWidth: 2,
//                                       color: AppColors.buttonPrimary)),
//                             );
//                           },
//                           errorBuilder: (_, __, ___) => SizedBox(
//                             width: qrSize,
//                             height: qrSize,
//                             child: const Center(
//                                 child: Icon(Icons.qr_code_2,
//                                     size: 48, color: Colors.grey)),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//                       Text(
//                         '₹${grandTotal.toStringAsFixed(0)}',
//                         style: const TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                             color: AppColors.success),
//                       ),
//                     ]),
//                   ),
//                 ),
//             const SizedBox(height: 8),
//             Text(
//               'Scan the QR code with any UPI app to pay ₹${grandTotal.toStringAsFixed(0)}, then fill in the details below.',
//               style: TextStyle(fontSize: 11, color: Colors.grey[600]),
//             ),
//
//             const SizedBox(height: 16),
//             const Divider(color: Color(0xFFEEEEEE)),
//             const SizedBox(height: 12),
//
//             // ── Step 2: Copy owner's number + screenshot ───────────────
//             _stepLabel('2', 'Copy Number & Attach Screenshot'),
//             const SizedBox(height: 4),
//             Text(
//               'If QR scan doesn\'t work, copy the number above and pay via UPI manually. Then attach a payment screenshot.',
//               style: TextStyle(fontSize: 11, color: Colors.grey[600]),
//             ),
//             const SizedBox(height: 10),
//
//             // Stack vertically on very narrow widths, side-by-side otherwise
//             isNarrow
//                 ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
//               _phoneDisplayBox(),
//               const SizedBox(height: 10),
//               Align(
//                 alignment: Alignment.centerLeft,
//                 child: _screenshotPicker(),
//               ),
//             ])
//                 : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//               Expanded(child: _phoneDisplayBox()),
//               const SizedBox(width: 10),
//               _screenshotPicker(),
//             ]),
//
//             const SizedBox(height: 10),
//
//             // Checklist
//             // Checklist
//             Wrap(spacing: 16, runSpacing: 6, children: [
//               _upiCheck(_customerPhone.isNotEmpty, 'Number available'),
//               _upiCheck(_paymentScreenshot != null, 'Screenshot attached'),
//             ]),
//           ]),
//         );
//       },
//     );
//   }
//
//   Widget _phoneDisplayBox() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
//       decoration: BoxDecoration(
//         color: Colors.grey[100],
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: Colors.grey[300]!),
//       ),
//       child: Row(children: [
//         Expanded(
//           child: _phoneLoading
//               ? const Text('Loading...',
//               style: TextStyle(fontSize: 14, color: Colors.grey))
//               : Text(
//             _customerPhone.isNotEmpty
//                 ? _customerPhone
//                 : 'No registered number found',
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: _customerPhone.isNotEmpty
//                     ? Colors.black87
//                     : Colors.red),
//           ),
//         ),
//         if (_customerPhone.isNotEmpty) ...[
//           const SizedBox(width: 8),
//           GestureDetector(
//             onTap: () => _copyPhoneNumber(_customerPhone),
//             child: Container(
//               padding: const EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: AppColors.buttonPrimary.withOpacity(0.08),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(Icons.copy,
//                   size: 16, color: AppColors.buttonPrimary),
//             ),
//           ),
//         ],
//       ]),
//     );
//   }
//
//   void _copyPhoneNumber(String number) {
//     Clipboard.setData(ClipboardData(text: number));
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('Number copied!'),
//         duration: Duration(seconds: 2),
//         backgroundColor: Colors.green,
//       ),
//     );
//   }
//
//   Widget _screenshotPicker() {
//     return GestureDetector(
//       onTap: _pickScreenshot,
//       child: _paymentScreenshot == null
//           ? DottedBorder(
//         color: AppColors.floatingCartBg,
//         strokeWidth: 1.5,
//         dashPattern: const [6, 3],
//         borderType: BorderType.RRect,
//         radius: const Radius.circular(10),
//         child: Container(
//           width: 64,
//           height: 56,
//           alignment: Alignment.center,
//           child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Icon(Icons.attach_file,
//                     color:  AppColors.floatingCartBg, size: 20),
//                 const SizedBox(height: 2),
//                 Text('Attach',
//                     style: TextStyle(
//                         fontSize: 10,
//                         color: Colors.black87,
//                         fontWeight: FontWeight.w500)),
//               ]),
//         ),
//       )
//           : Stack(children: [
//         ClipRRect(
//           borderRadius: BorderRadius.circular(10),
//           child: Image.file(
//             File(_paymentScreenshot!.path),
//             width: 64,
//             height: 56,
//             fit: BoxFit.cover,
//           ),
//         ),
//         Positioned(
//           top: -4,
//           right: -4,
//           child: GestureDetector(
//             onTap: () =>
//                 setState(() => _paymentScreenshot = null),
//             child: Container(
//               decoration: const BoxDecoration(
//                   color: Colors.red,
//                   shape: BoxShape.circle),
//               child: const Icon(Icons.close,
//                   size: 16, color: Colors.white),
//             ),
//           ),
//         ),
//       ]),
//     );
//   }
//
//   // ── Step label ────────────────────────────────────────────────────────────
//   Widget _stepLabel(String number, String label) {
//     return Row(children: [
//       Container(
//         width: 24,
//         height: 24,
//         alignment: Alignment.center,
//         decoration: const BoxDecoration(
//           color: AppColors.floatingCartBg,
//           shape: BoxShape.circle,
//         ),
//         child: Text(number,
//             style: const TextStyle(
//                 fontSize: 12,
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold)),
//       ),
//       const SizedBox(width: 8),
//       Expanded(
//         child: Text(label,
//             style: const TextStyle(
//                 fontSize: 14, fontWeight: FontWeight.w600)),
//       ),
//     ]);
//   }
//
//   // ── UPI check chip ────────────────────────────────────────────────────────
//   Widget _upiCheck(bool done, String label) {
//     return Row(mainAxisSize: MainAxisSize.min, children: [
//       Icon(
//         done ? Icons.check_circle : Icons.radio_button_unchecked,
//         size: 14,
//         color: done ? Colors.green : Colors.grey[400],
//       ),
//       const SizedBox(width: 4),
//       Text(
//         label,
//         style: TextStyle(
//           fontSize: 11,
//           color: done ? Colors.green : Colors.grey[500],
//           fontWeight: FontWeight.w500,
//         ),
//       ),
//     ]);
//   }
//
//   // ── Wallet section ────────────────────────────────────────────────────────
//   Widget _buildWalletSection(double grandTotal) {
//     final applied = _walletApplied(grandTotal);
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: _useWallet
//               ? Colors.green.withOpacity(0.5)
//               : Colors.grey[300]!,
//           width: _useWallet ? 1.5 : 1,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(children: [
//         Container(
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: AppColors.floatingCartBg.withOpacity(0.08),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: const Icon(Icons.account_balance_wallet_outlined,
//               color: AppColors.floatingCartBg, size: 20),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//             const Text('Use Wallet Balance',
//                 style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87)),
//             const SizedBox(height: 2),
//             Text(
//               _useWallet
//                   ? 'Applying ₹${applied.toStringAsFixed(0)} of ₹${_walletBalance.toStringAsFixed(0)}'
//                   : 'Available: ₹${_walletBalance.toStringAsFixed(0)}',
//               style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//             ),
//           ]),
//         ),
//         Switch(
//           value: _useWallet,
//           activeColor: AppColors.buttonPrimary,
//           onChanged: (v) {
//             if (v && _walletBalance < grandTotal) {
//               _showToast(
//                 context,
//                 'Wallet balance (₹${_walletBalance.toStringAsFixed(0)}) is less than the order total. '
//                     'You can only use wallet when it fully covers the order amount.',
//               );
//               return; // don't flip the switch
//             }
//             setState(() => _useWallet = v);
//           },
//         ),
//       ]),
//     );
//   }
//
//   // ── Coupon section ────────────────────────────────────────────────────────
//   Widget _buildCouponSection(double cartTotal) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: _couponApplied
//               ? Colors.green.withOpacity(0.5)
//               : Colors.grey[300]!,
//           width: _couponApplied ? 1.5 : 1,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
//           child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//             Row(children: [
//               Container(
//                 padding: const EdgeInsets.all(7),
//                 decoration: BoxDecoration(
//                   color: AppColors.floatingCartBg.withOpacity(0.08),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Icon(Icons.local_offer_outlined,
//                     color: AppColors.floatingCartBg, size: 18),
//               ),
//               const SizedBox(width: 10),
//               const Text('Apply Coupon',
//                   style: TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87)),
//               const Spacer(),
//               if (_couponApplied)
//                 Container(
//                   padding:
//                   const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                   decoration: BoxDecoration(
//                       color: Colors.green,
//                       borderRadius: BorderRadius.circular(10)),
//                   child: const Text('APPLIED',
//                       style: TextStyle(
//                           fontSize: 10,
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold)),
//                 )
//               else if (_couponLoading)
//                 const SizedBox(
//                   width: 16,
//                   height: 16,
//                   child: CircularProgressIndicator(
//                       strokeWidth: 2,  color: AppColors.floatingCartBg),
//                 ),
//             ]),
//             if (!_couponApplied && !_couponLoading) ...[
//               const SizedBox(height: 8),
//               GestureDetector(
//                 onTap: () => _openAllCoupons(cartTotal),
//                 child: Row(mainAxisSize: MainAxisSize.min, children: [
//                   Text('View all coupons',
//                       style: TextStyle(
//                           fontSize: 13,
//                           color: Colors.grey[600],
//                           fontWeight: FontWeight.w500)),
//                   const SizedBox(width: 4),
//                   Container(
//                     padding: const EdgeInsets.all(3),
//                     decoration: BoxDecoration(
//                       color: AppColors.floatingCartBg.withOpacity(0.08),
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Icon(Icons.keyboard_arrow_down_rounded,
//                         size: 16,  color: AppColors.floatingCartBg),
//                   ),
//                 ]),
//               ),
//             ],
//           ]),
//         ),
//         const Divider(height: 1, color: Color(0xFFF0F0F0)),
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
//           child: _couponApplied
//               ? _buildAppliedCoupon()
//               : _buildCouponInput(cartTotal),
//         ),
//       ]),
//     );
//   }
//
//   Widget _buildCouponInput(double cartTotal) {
//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Row(children: [
//         Expanded(
//           child: TextFormField(
//             controller: _couponController,
//             textCapitalization: TextCapitalization.characters,
//             style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 letterSpacing: 1.2),
//             decoration: InputDecoration(
//               hintText: 'Enter coupon code',
//               hintStyle: TextStyle(
//                   color: Colors.grey[400],
//                   fontWeight: FontWeight.normal,
//                   letterSpacing: 0),
//               filled: true,
//               fillColor: const Color(0xFFF8F8F8),
//               contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 14, vertical: 12),
//               border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: BorderSide(color: Colors.grey[300]!)),
//               enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: BorderSide(color: Colors.grey[300]!)),
//               focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: const BorderSide(
//                       color: AppColors.buttonPrimary, width: 1.5)),
//             ),
//             onChanged: (_) {
//               if (_couponError.isNotEmpty) {
//                 setState(() => _couponError = '');
//               }
//             },
//           ),
//         ),
//         const SizedBox(width: 10),
//         SizedBox(
//           height: 48,
//           child: ElevatedButton(
//             onPressed:
//             _couponLoading ? null : () => _applyCoupon(cartTotal),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.buttonPrimary,
//               disabledBackgroundColor: AppColors.buttonPrimaryDisabled,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//               elevation: 0,
//               padding: const EdgeInsets.symmetric(horizontal: 18),
//             ),
//             child: _couponLoading
//                 ? const SizedBox(
//                 width: 18,
//                 height: 18,
//                 child: CircularProgressIndicator(
//                     color: Colors.white, strokeWidth: 2))
//                 : const Text('APPLY',
//                 style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 13)),
//           ),
//         ),
//       ]),
//       if (_couponError.isNotEmpty) ...[
//         const SizedBox(height: 8),
//         Row(children: [
//           const Icon(Icons.error_outline, size: 14, color: Colors.red),
//           const SizedBox(width: 4),
//           Expanded(
//               child: Text(_couponError,
//                   style: const TextStyle(
//                       fontSize: 12, color: Colors.red))),
//         ]),
//       ],
//     ]);
//   }
//
//   Widget _buildAppliedCoupon() {
//     return Row(children: [
//       const Icon(Icons.check_circle, color: Colors.green, size: 20),
//       const SizedBox(width: 10),
//       Expanded(
//         child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(_couponCode,
//                   style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87,
//                       letterSpacing: 1)),
//               const SizedBox(height: 2),
//               Text('You save ₹${_couponDiscount.toStringAsFixed(0)}',
//                   style: const TextStyle(
//                       fontSize: 12, color: Colors.green)),
//             ]),
//       ),
//       GestureDetector(
//         onTap: _removeCoupon,
//         child: Container(
//           padding:
//           const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//           decoration: BoxDecoration(
//               border: Border.all(color: Colors.red.withOpacity(0.4)),
//               borderRadius: BorderRadius.circular(8)),
//           child: const Text('Remove',
//               style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.red,
//                   fontWeight: FontWeight.w600)),
//         ),
//       ),
//     ]);
//   }
//
//   Widget _paymentOption(String value, String title, String subtitle) =>
//       RadioListTile<String>(
//         value: value,
//         groupValue: _selectedPayment,
//
//         onChanged: (v) {
//           setState(() => _selectedPayment = v!);
//           if (v!.toUpperCase().contains('UPI') && _qrImageUrl.isEmpty && !_qrLoading) {
//             final amount = (_cartGrandTotalFallback > 0)
//                 ? _cartGrandTotalFallback
//                 : widget.finalTotal;
//             _loadQrCode(amount);
//           }
//         },
//
//         activeColor: AppColors.buttonPrimary,
//         title: Text(title,
//             style: const TextStyle(
//                 fontSize: 16, fontWeight: FontWeight.w600)),
//         subtitle: Text(subtitle,
//             style: const TextStyle(fontSize: 14)),
//       );
//
//   // Best-effort grand total available outside the Consumer<CartModel>
//   // builder (used only to kick off the QR fetch as soon as UPI is tapped).
//   double get _cartGrandTotalFallback => _finalTotal;
//
//   Widget _summaryRow(String label, String value,
//       {Color? valueColor, bool bold = false}) =>
//       Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label,
//               style: TextStyle(
//                   fontSize: 14,
//                   color: bold ? Colors.black : Colors.grey[700],
//                   fontWeight:
//                   bold ? FontWeight.bold : FontWeight.normal)),
//           Text(value,
//               style: TextStyle(
//                   fontSize: 14,
//                   fontWeight:
//                   bold ? FontWeight.bold : FontWeight.w500,
//                   color: valueColor ??
//                       (bold ? Colors.black : Colors.black87))),
//         ],
//       );
//
//   void _showToast(BuildContext context, String message) {
//     ScaffoldMessenger.of(context).hideCurrentSnackBar();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(children: [
//           const Icon(Icons.error_outline, color: Colors.white, size: 20),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               message,
//               style: const TextStyle(fontSize: 13, color: Colors.white),
//             ),
//           ),
//         ]),
//         backgroundColor: Colors.red[600],
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.all(12),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         duration: const Duration(seconds: 3),
//       ),
//     );
//   }
//
//   // Guards against the backend leaking a raw PHP stack trace / file path
//   // into the message — falls back to a clean generic message instead.
//   String _cleanMessage(String msg) {
//     if (msg.contains('/home/') || msg.contains('.php') || msg.length > 150) {
//       return 'Order could not be placed. Please try again.';
//     }
//     return msg;
//   }
// }
//
// class _AllCouponsScreen extends StatefulWidget {
//   final List<CouponModel> coupons;
//   final double            cartTotal;
//   final String            token;
//
//   const _AllCouponsScreen({
//     required this.coupons,
//     required this.cartTotal,
//     required this.token,
//   });
//
//   @override
//   State<_AllCouponsScreen> createState() => _AllCouponsScreenState();
// }
//
// class _AllCouponsScreenState extends State<_AllCouponsScreen> {
//   String? _applyingCode; // code currently being validated against backend
//
//   Future<void> _applyCoupon(CouponModel coupon) async {
//     setState(() => _applyingCode = coupon.code);
//
//     final result = await CouponApiService.applyCoupon(
//       token:      widget.token,
//       couponCode: coupon.code,
//       grandTotal: widget.cartTotal,
//     );
//
//     if (!mounted) return;
//     setState(() => _applyingCode = null);
//
//     if (!result.success) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text(result.error.isNotEmpty ? result.error : 'Could not apply coupon'),
//         backgroundColor: Colors.red,
//       ));
//       return;
//     }
//
//     // Backend confirmed — pop back with the validated coupon (has discountAmount).
//     Navigator.pop(context, result.coupon);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cartTotal = widget.cartTotal;
//     final coupons   = widget.coupons;
//     final eligible = coupons.where((c) => c.isEligible(cartTotal)).toList();
//     final blocked  = coupons.where((c) => !c.isEligible(cartTotal)).toList();
//     final sorted   = [...eligible, ...blocked];
//
//     return Scaffold(
//       backgroundColor: AppColors.white,
//       appBar: AppBar(
//         backgroundColor: AppColors.appBarBg,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text('Available Coupons',
//             style: TextStyle(
//                 color: AppColors.appBarText,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18)),
//         bottom: PreferredSize(
//
//           preferredSize: const Size.fromHeight(1),
//           child: Container(height: 1, color: Colors.grey[200]),
//         ),
//       ),
//       body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Container(
//           color: Colors.white,
//           padding:
//           const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//           child: Row(children: [
//             const Icon(Icons.shopping_cart_outlined,
//                 size: 16,  color: AppColors.floatingCartBg),
//             const SizedBox(width: 8),
//             Text('Your cart total: ',
//                 style:
//                 TextStyle(fontSize: 13, color: Colors.grey[600])),
//             Text('₹${cartTotal.toStringAsFixed(0)}',
//                 style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: AppColors.textDark)),
//             const Spacer(),
//             if (eligible.isNotEmpty)
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 8, vertical: 3),
//                 decoration: BoxDecoration(
//                     color: AppColors.success.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(6)),
//                 child: Text('${eligible.length} applicable',
//                     style: const TextStyle(
//                         fontSize: 11,
//                         color: AppColors.success,
//                         fontWeight: FontWeight.bold)),
//               ),
//           ]),
//         ),
//         if (coupons.isEmpty)
//           const Expanded(
//             child: Center(
//               child: Column(mainAxisSize: MainAxisSize.min, children: [
//                 Icon(Icons.local_offer_outlined,
//                     size: 52, color: Colors.grey),
//                 SizedBox(height: 14),
//                 Text('No coupons available',
//                     style: TextStyle(
//                         fontSize: 15,
//                         color: Colors.grey,
//                         fontWeight: FontWeight.w600)),
//               ]),
//             ),
//           )
//         else
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
//               itemCount:
//               sorted.length + (blocked.isNotEmpty ? 1 : 0),
//               itemBuilder: (context, index) {
//                 if (blocked.isNotEmpty && index == eligible.length) {
//                   return Padding(
//                     padding:
//                     const EdgeInsets.only(top: 8, bottom: 14),
//                     child: Row(children: [
//                       const Icon(Icons.lock_outline,
//                           size: 14, color: Colors.grey),
//                       const SizedBox(width: 6),
//                       Text('Not applicable for your cart',
//                           style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey[500],
//                               fontWeight: FontWeight.w600)),
//                       const SizedBox(width: 8),
//                       Expanded(
//                           child: Divider(color: Colors.grey[300])),
//                     ]),
//                   );
//                 }
//                 final i = (blocked.isNotEmpty && index > eligible.length)
//                     ? index - 1
//                     : index;
//                 final coupon = sorted[i];
//                 final isElg  = coupon.isEligible(cartTotal);
//                 final disc   = coupon.computeDiscount(cartTotal);
//
//                 return _CouponCard(
//                   coupon:     coupon,
//                   isEligible: isElg,
//                   discount:   disc,
//                   cartTotal:  cartTotal,
//                   isApplying: _applyingCode == coupon.code,
//                   onTap:      isElg && _applyingCode == null
//                       ? () => _applyCoupon(coupon)
//                       : null,
//                 );
//               },
//             ),
//           ),
//       ]),
//     );
//   }
// }
//
// class _CouponCard extends StatelessWidget {
//   final CouponModel   coupon;
//   final bool          isEligible;
//   final double        discount;
//   final double        cartTotal;
//   final bool          isApplying;
//   final VoidCallback? onTap;
//
//   const _CouponCard({
//     required this.coupon,
//     required this.isEligible,
//     required this.discount,
//     required this.cartTotal,
//     this.isApplying = false,
//     this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final Color accent =
//     isEligible ?   AppColors.floatingCartBg : Colors.grey;
//
//     return Opacity(
//       opacity: isEligible ? 1.0 : 0.55,
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 12),
//         decoration: BoxDecoration(
//           color: isEligible ? Colors.white : const Color(0xFFF5F5F5),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: isEligible
//                 ? accent.withOpacity(0.3)
//                 : Colors.grey[300]!,
//             width: isEligible ? 1.5 : 1,
//           ),
//           boxShadow: isEligible
//               ? [
//             BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 8,
//                 offset: const Offset(0, 2))
//           ]
//               : [],
//         ),
//         child: Column(children: [
//           Container(
//             padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
//             decoration: BoxDecoration(
//               color: accent.withOpacity(isEligible ? 0.05 : 0.03),
//               borderRadius:
//               const BorderRadius.vertical(top: Radius.circular(12)),
//             ),
//             child: Wrap(
//               crossAxisAlignment: WrapCrossAlignment.center,
//               spacing: 12,
//               runSpacing: 8,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color:
//                     isEligible ? accent : Colors.grey[400],
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Text(coupon.code,
//                       style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 13,
//                           fontWeight: FontWeight.bold,
//                           letterSpacing: 1.2)),
//                 ),
//                 Text(coupon.title,
//                     style: TextStyle(
//                         fontSize: 15,
//                         fontWeight: FontWeight.bold,
//                         color: isEligible
//                             ? Colors.black87
//                             : Colors.grey[500])),
//                 if (isEligible)
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 10, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: AppColors.success.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(
//                           color: AppColors.success.withOpacity(0.3)),
//                     ),
//                     child: Text(
//                         'Save ₹${discount.toStringAsFixed(0)}',
//                         style: const TextStyle(
//                             fontSize: 11,
//                             color: AppColors.success,
//                             fontWeight: FontWeight.bold)),
//                   ),
//               ],
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
//             child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(coupon.description,
//                       style: TextStyle(
//                           fontSize: 13,
//                           color: isEligible
//                               ? Colors.grey[700]
//                               : Colors.grey[400])),
//                   const SizedBox(height: 10),
//                   Wrap(spacing: 8, runSpacing: 6, children: [
//                     _chip(
//                         Icons.currency_rupee,
//                         'Min ₹${coupon.minimumTotal.toStringAsFixed(0)}',
//                         isEligible &&
//                             cartTotal >= coupon.minimumTotal),
//                     if (coupon.type == 'P' && coupon.total > 0)
//                       _chip(
//                           Icons.local_offer_outlined,
//                           'Upto ₹${coupon.total.toStringAsFixed(0)} off',
//                           isEligible),
//                   ]),
//                   if (!isEligible) ...[
//                     const SizedBox(height: 10),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 10, vertical: 7),
//                       decoration: BoxDecoration(
//                         color: Colors.orange[50],
//                         borderRadius: BorderRadius.circular(6),
//                         border:
//                         Border.all(color: Colors.orange[200]!),
//                       ),
//                       child: Row(children: [
//                         Icon(Icons.info_outline,
//                             size: 13, color: Colors.orange[700]),
//                         const SizedBox(width: 6),
//                         Expanded(
//                             child: Text(
//                               cartTotal < coupon.minimumTotal
//                                   ? 'Add ₹${(coupon.minimumTotal - cartTotal).toStringAsFixed(0)} more to unlock'
//                                   : 'Not applicable for your cart total',
//                               style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.orange[800]),
//                             )),
//                       ]),
//                     ),
//                   ],
//                   if (isEligible) ...[
//                     const SizedBox(height: 14),
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: isApplying ? null : onTap,
//                         style: ElevatedButton.styleFrom(
//                           // backgroundColor: const Color(0xFFFF0080),
//                           backgroundColor: AppColors.buttonPrimary,
//                           disabledBackgroundColor: AppColors.buttonPrimaryDisabled,
//                           padding: const EdgeInsets.symmetric(
//                               vertical: 12),
//                           shape: RoundedRectangleBorder(
//                               borderRadius:
//                               BorderRadius.circular(8)),
//                           elevation: 0,
//                         ),
//                         child: isApplying
//                             ? const SizedBox(
//                             width: 18,
//                             height: 18,
//                             child: CircularProgressIndicator(
//                                 color: Colors.white, strokeWidth: 2))
//                             : Text(
//                             'Apply  •  Save ₹${discount.toStringAsFixed(0)}',
//                             style: const TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 13)),
//                       ),
//                     ),
//                   ],
//                 ]),
//           ),
//         ]),
//       ),
//     );
//   }
//
//   Widget _chip(IconData icon, String label, bool met) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//     decoration: BoxDecoration(
//       color: met
//           ? Colors.green.withOpacity(0.08)
//           : Colors.grey[100],
//       borderRadius: BorderRadius.circular(6),
//       border: Border.all(
//           color: met
//               ? Colors.green.withOpacity(0.3)
//               : Colors.grey[300]!),
//     ),
//     child: Row(mainAxisSize: MainAxisSize.min, children: [
//       Icon(
//           met ? Icons.check_circle_outline : icon,
//           size: 12,
//           color: met ? Colors.green : Colors.grey[500]),
//       const SizedBox(width: 4),
//       Text(label,
//           style: TextStyle(
//               fontSize: 11,
//               color: met ? Colors.green : Colors.grey[500],
//               fontWeight: FontWeight.w500)),
//     ]),
//   );
// }
//
// class _OrderSuccessScreen extends StatelessWidget {
//   final String         orderId;
//   final double         total;
//   final String         paymentLabel;
//   final AddressModel   address;
//   final List<CartItem> purchasedItems;
//   final VoidCallback   onContinue;
//   final double         deliveryFee;
//   final double         subTotal;
//
//   const _OrderSuccessScreen({
//     required this.orderId,
//     required this.total,
//     required this.paymentLabel,
//     required this.address,
//     required this.purchasedItems,
//     required this.onContinue,
//     required this.deliveryFee,
//     required this.subTotal,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final maxContentWidth = screenWidth > 900
//         ? 720.0
//         : screenWidth > 600
//         ? 560.0
//         : double.infinity;
//     final horizontalPad = screenWidth > 600 ? 32.0 : 20.0;
//
//     return Scaffold(
//       backgroundColor: const Color(0xFFFFFFFF),
//       body: SafeArea(
//         child: Column(children: [
//           Expanded(
//             child: SingleChildScrollView(
//               child: Center(
//                 child: ConstrainedBox(
//                   constraints: BoxConstraints(maxWidth: maxContentWidth),
//                   child: Padding(
//                     padding: EdgeInsets.fromLTRB(
//                         horizontalPad, 36, horizontalPad, 20),
//                     child: Column(children: [
//                       Container(
//                         padding: const EdgeInsets.all(24),
//                         decoration: const BoxDecoration(
//                             color: AppColors.successLight, shape: BoxShape.circle),
//                         child: const Icon(Icons.check_circle,
//                             color: AppColors.success, size: 80),
//                       ),
//                       const SizedBox(height: 20),
//                       const Text('Order Placed\nSuccessfully!',
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                               fontSize: 28,
//                               fontWeight: FontWeight.bold,
//                               height: 1.3)),
//                       const SizedBox(height: 16),
//                       if (orderId.isNotEmpty)
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 22, vertical: 9),
//                           decoration: BoxDecoration(
//                             color: AppColors.accentDark.withOpacity(0.07),
//                             borderRadius: BorderRadius.circular(30),
//                             border: Border.all(
//                                 color:
//                                 AppColors.accentDark.withOpacity(0.4),
//                                 width: 1.2),
//                           ),
//                           child: Text('Order ID: #$orderId',
//                               style: const TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                   color: AppColors.textDark)),
//                         ),
//                       const SizedBox(height: 28),
//                       Container(
//                         width: double.infinity,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(16),
//                           boxShadow: [
//                             BoxShadow(
//                                 color: Colors.black.withOpacity(0.06),
//                                 blurRadius: 12,
//                                 offset: const Offset(0, 4))
//                           ],
//                         ),
//                         child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Padding(
//                                 padding:
//                                 const EdgeInsets.fromLTRB(20, 20, 20, 16),
//                                 child: Wrap(
//                                     alignment: WrapAlignment.spaceBetween,
//                                     crossAxisAlignment: WrapCrossAlignment.center,
//                                     runSpacing: 12,
//                                     children: [
//                                       Column(
//                                           crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                           children: [
//                                             Text('Total Amount',
//                                                 style: TextStyle(
//                                                     fontSize: 12,
//                                                     color: Colors.grey[500])),
//                                             const SizedBox(height: 3),
//                                             Text(
//                                                 '₹${total.toStringAsFixed(0)}',
//                                                 style: const TextStyle(
//                                                     fontSize: 26,
//                                                     fontWeight: FontWeight.bold,
//                                                     color: AppColors.textDark)),
//                                           ]),
//                                       Container(
//                                         padding: const EdgeInsets.symmetric(
//                                             horizontal: 12, vertical: 8),
//                                         decoration: BoxDecoration(
//                                           color:  AppColors.floatingCartBg
//                                               .withOpacity(0.08),
//                                           borderRadius:
//                                           BorderRadius.circular(10),
//                                           border: Border.all(
//                                               color: AppColors.floatingCartBg
//                                                   .withOpacity(0.2)),
//                                         ),
//                                         child: Column(
//                                             crossAxisAlignment:
//                                             CrossAxisAlignment.end,
//                                             children: [
//                                               Text('Payment',
//                                                   style: TextStyle(
//                                                       fontSize: 11,
//                                                       color: Colors.grey[500])),
//                                               const SizedBox(height: 3),
//                                               Row(children: [
//                                                 const Icon(
//                                                     Icons.payments_outlined,
//                                                     size: 14,
//                                                     color: AppColors.floatingCartBg),
//                                                 const SizedBox(width: 4),
//                                                 Text(paymentLabel,
//                                                     style: const TextStyle(
//                                                         fontSize: 13,
//                                                         fontWeight:
//                                                         FontWeight.bold,
//                                                         color: AppColors.floatingCartBg)),
//                                               ]),
//                                             ]),
//                                       ),
//                                     ]),
//                               ),
//                               _div(),
//                               Padding(
//                                 padding:
//                                 const EdgeInsets.fromLTRB(20, 14, 20, 10),
//                                 child: Row(children: [
//                                   Container(
//                                     padding: const EdgeInsets.all(6),
//                                     decoration: BoxDecoration(
//                                         color: AppColors.floatingCartBg
//                                             .withOpacity(0.1),
//                                         borderRadius:
//                                         BorderRadius.circular(8)),
//                                     child: const Icon(
//                                         Icons.shopping_bag_outlined,
//                                         size: 16,
//                                         color: AppColors.floatingCartBg),
//                                   ),
//                                   const SizedBox(width: 10),
//                                   Expanded(
//                                     child: Text(
//                                         'Items Purchased  (${purchasedItems.length})',
//                                         style: const TextStyle(
//                                             fontSize: 15,
//                                             fontWeight: FontWeight.bold,
//                                             color: Colors.black87)),
//                                   ),
//                                 ]),
//                               ),
//                               ListView.separated(
//                                 shrinkWrap: true,
//                                 physics: const NeverScrollableScrollPhysics(),
//                                 itemCount: purchasedItems.length,
//                                 separatorBuilder: (_, __) => Divider(
//                                     height: 1,
//                                     indent: 72,
//                                     color: Colors.grey[100]),
//                                 itemBuilder: (_, i) =>
//                                     _ItemRow(item: purchasedItems[i]),
//                               ),
//                               Container(
//                                 margin:
//                                 const EdgeInsets.fromLTRB(16, 8, 16, 0),
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 12, vertical: 8),
//                                 decoration: BoxDecoration(
//                                     color: const Color(0xFFF5F5F5),
//                                     borderRadius: BorderRadius.circular(8)),
//                                 child: Column(children: [
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       Expanded(
//                                         child: Text(
//                                           '${purchasedItems.fold(0, (s, i) => s + i.quantity)} item(s)',
//                                           style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                                         ),
//                                       ),
//                                       Text('₹${subTotal.toStringAsFixed(0)}',
//                                           style: TextStyle(fontSize: 12, color: Colors.grey[600])),
//                                     ],
//                                   ),
//                                   if (subTotal + deliveryFee > total) ...[
//                                     const SizedBox(height: 4),
//                                     Row(
//                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                       children: [
//                                         Row(children: [
//                                           Icon(Icons.local_offer_outlined, size: 13, color: Colors.green),
//                                           const SizedBox(width: 4),
//                                           Text('Discount Applied',
//                                               style: TextStyle(fontSize: 12, color: Colors.green)),
//                                         ]),
//                                         Text(
//                                           '- ₹${(subTotal + deliveryFee - total).toStringAsFixed(0)}',
//                                           style: const TextStyle(
//                                               fontSize: 12,
//                                               fontWeight: FontWeight.w600,
//                                               color: Colors.green),
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                   const SizedBox(height: 4),
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       Row(children: [
//                                         Icon(Icons.local_shipping_outlined,
//                                             size: 13, color: deliveryFee > 0 ? Colors.grey[600] : Colors.green),
//                                         const SizedBox(width: 4),
//                                         Text(
//                                           deliveryFee > 0 ? 'Delivery' : 'Free Delivery',
//                                           style: TextStyle(
//                                               fontSize: 12,
//                                               color: deliveryFee > 0 ? Colors.grey[600] : Colors.green),
//                                         ),
//                                       ]),
//                                       Text(
//                                         deliveryFee > 0 ? '₹${deliveryFee.toStringAsFixed(0)}' : 'FREE',
//                                         style: TextStyle(
//                                             fontSize: 12,
//                                             fontWeight: FontWeight.w600,
//                                             color: deliveryFee > 0 ? Colors.grey[600] : Colors.green),
//                                       ),
//                                     ],
//                                   ),
//                                   const Divider(height: 12),
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       const Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
//                                       Text('₹${total.toStringAsFixed(0)}',
//                                           style: const TextStyle(
//                                               fontSize: 14,
//                                               fontWeight: FontWeight.bold,
//                                               color: AppColors.success)),
//                                     ],
//                                   ),
//                                 ]),
//                               ),
//                               _div(top: 16),
//                               Padding(
//                                 padding: const EdgeInsets.fromLTRB(
//                                     20, 14, 20, 20),
//                                 child: Column(
//                                     crossAxisAlignment:
//                                     CrossAxisAlignment.start,
//                                     children: [
//                                       Row(children: [
//                                         Container(
//                                           padding: const EdgeInsets.all(6),
//                                           decoration: BoxDecoration(
//                                               color: AppColors.success
//                                                   .withOpacity(0.1),
//                                               borderRadius:
//                                               BorderRadius.circular(8)),
//                                           child: const Icon(
//                                               Icons.location_on_outlined,
//                                               size: 16,
//                                               color: AppColors.success),
//                                         ),
//                                         const SizedBox(width: 10),
//                                         const Text('Delivering to',
//                                             style: TextStyle(
//                                                 fontSize: 15,
//                                                 fontWeight: FontWeight.bold,
//                                                 color: Colors.black87)),
//                                       ]),
//                                       const SizedBox(height: 12),
//                                       Text(address.fullName,
//                                           style: const TextStyle(
//                                               fontSize: 15,
//                                               fontWeight: FontWeight.w600)),
//                                       const SizedBox(height: 4),
//                                       Text(address.singleLine,
//                                           style: TextStyle(
//                                               fontSize: 13,
//                                               color: Colors.grey[600])),
//                                       const SizedBox(height: 6),
//                                       Row(children: [
//                                         Icon(Icons.phone_outlined,
//                                             size: 14,
//                                             color: Colors.grey[500]),
//                                         const SizedBox(width: 5),
//                                         Flexible(
//                                           child: Text(address.phone,
//                                               style: TextStyle(
//                                                   fontSize: 13,
//                                                   color: Colors.grey[600])),
//                                         ),
//                                       ]),
//                                     ]),
//                               ),
//                             ]),
//                       ),
//                       const SizedBox(height: 16),
//                       Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: AppColors.success.withOpacity(0.07),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(
//                               color:
//                               AppColors.success.withOpacity(0.2)),
//                         ),
//                         child: Row(children: [
//                           const Icon(Icons.local_shipping_outlined,
//                               color: AppColors.success, size: 26),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text('Estimated Delivery',
//                                       style: TextStyle(
//                                           fontSize: 13,
//                                           fontWeight: FontWeight.bold,
//                                           color: AppColors.success)),
//                                   const SizedBox(height: 2),
//                                   Text(
//                                       'Your order will be delivered soon!',
//                                       style: TextStyle(
//                                           fontSize: 12,
//                                           color: Colors.grey[600])),
//                                 ]),
//                           ),
//                         ]),
//                       ),
//                     ]),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           Container(
//             color: Colors.white,
//             padding: EdgeInsets.fromLTRB(horizontalPad, 12, horizontalPad, 24),
//             child: Center(
//               child: ConstrainedBox(
//                 constraints: BoxConstraints(maxWidth: maxContentWidth),
//                 child: SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: onContinue,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.buttonPrimary,
//                       padding: const EdgeInsets.symmetric(vertical: 18),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14)),
//                       elevation: 0,
//                     ),
//                     child: const Text('CONTINUE SHOPPING',
//                         style: TextStyle(
//                             color: Color(0xFFFFFFFF),
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             letterSpacing: 0.8)),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ]),
//       ),
//     );
//   }
//
//   Widget _div({double top = 0}) => Container(
//       margin: EdgeInsets.only(top: top),
//       height: 1,
//       color: Colors.grey[100]);
// }
//
// // ── Item Row ──────────────────────────────────────────────────────────────────
// class _ItemRow extends StatelessWidget {
//   final CartItem item;
//   const _ItemRow({required this.item});
//
//   @override
//   Widget build(BuildContext context) {
//     final p     = item.product;
//     final total = p.price * item.quantity;
//     final base  = ApiConfig.imageBase;
//     String imgUrl = '';
//     if (p.imageUrl.isNotEmpty && p.imageUrl != 'no_image.png') {
//       imgUrl = p.imageUrl.startsWith('http')
//           ? p.imageUrl
//           : '$base${p.imageUrl}';
//     } else if (p.image.isNotEmpty && p.image != 'no_image.png') {
//       imgUrl = p.image.startsWith('http')
//           ? p.image
//           : '$base${p.image}';
//     }
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//       child: Row(children: [
//         ClipRRect(
//           borderRadius: BorderRadius.circular(8),
//           child: Container(
//             width: 52,
//             height: 52,
//             color: const Color(0xFFF5F5F5),
//             child: imgUrl.isNotEmpty
//                 ? Image.network(imgUrl,
//                 fit: BoxFit.cover,
//                 errorBuilder: (_, __, ___) => _ph())
//                 : _ph(),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(p.name,
//                     style: const TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.black87),
//                     maxLines: 3,
//                     overflow: TextOverflow.ellipsis),
//                 const SizedBox(height: 5),
//                 Wrap(spacing: 6, runSpacing: 4, children: [
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 8, vertical: 2),
//                     decoration: BoxDecoration(
//                       color: AppColors.divider,
//                       borderRadius: BorderRadius.circular(4),
//                       border: Border.all(
//                           color: AppColors.floatingCartBg
//                               .withOpacity(0.3)),
//                     ),
//                     child: Text('Qty: ${item.quantity}',
//                         style: const TextStyle(
//                             fontSize: 11,
//                             color: AppColors.floatingCartBg,
//                             fontWeight: FontWeight.w600)),
//                   ),
//                   if (p.weight.isNotEmpty)
//                     Text(
//                       p.weight,
//                       style: TextStyle(fontSize: 11, color: Colors.grey[500]),
//                       overflow: TextOverflow.ellipsis,
//                       maxLines: 1,
//                     ),
//                 ]),
//               ]),
//         ),
//         const SizedBox(width: 8),
//         Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
//           Text('₹${total.toStringAsFixed(0)}',
//               style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                   color: AppColors.success)),
//           const SizedBox(height: 2),
//           Text('₹${p.price.toStringAsFixed(0)} each',
//               style:
//               TextStyle(fontSize: 10, color: Colors.grey[400])),
//         ]),
//       ]),
//     );
//   }
//
//   Widget _ph() => const Center(
//       child: Icon(Icons.image_not_supported,
//           color: Colors.grey, size: 20));
// }

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_color.dart';
import '../model/address_model.dart';
import '../model/cart_model.dart';
import '../services/Upi qr service.dart';
import '../services/api_config_service.dart';
import '../services/apply_coupon_service.dart';
import '../services/easy_upi_payment.dart';
import '../services/get_profile_service.dart';
import '../services/order_api_service.dart';
import '../services/session_manager.dart';
import '../services/store_profile_cache.dart';

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
  String _selectedPayment = '';

  AddressModel? _defaultAddress;

  final TextEditingController _couponController =
  TextEditingController();

  bool _couponApplied = false;
  bool _couponLoading = false;
  bool _placingOrder = false;
  bool _addrLoading = false;

  late double _deliveryFee;
  late double _finalTotal;

  String _couponCode = '';
  String _couponError = '';
  double _couponDiscount = 0.0;

  // ─────────────────────────────────────────────────────────────
  // UPI
  // ─────────────────────────────────────────────────────────────

  String _storeUpiId = '';
  String _storeUpiName = 'Store';
  bool _upiLoading = false;

  String _lastTransactionId = '';
  String _lastTransactionRefId = '';
  String _lastApprovalRefNo = '';
  String _lastResponseCode = '';
  String _lastPaymentAmount = '';

  // ─────────────────────────────────────────────────────────────
  // QR
  // ─────────────────────────────────────────────────────────────

  String _qrImageUrl = '';
  bool _qrLoading = false;
  String _qrError = '';

  // ─────────────────────────────────────────────────────────────
  // Wallet
  // ─────────────────────────────────────────────────────────────

  double _walletBalance = 0;
  bool _useWallet = false;

  // ─────────────────────────────────────────────────────────────
  // Payment methods
  // ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _paymentMethods =
      StoreProfileCache.paymentMethods;

  Timer? _paymentMethodsPollTimer;

  @override
  void initState() {
    super.initState();

    _defaultAddress = widget.selectedAddress;
    _deliveryFee = widget.deliveryFee;
    _finalTotal = widget.finalTotal;

    if (_paymentMethods.isNotEmpty) {
      _selectedPayment =
          _paymentMethods.first['name'].toString();
    }

    _loadCustomerPaymentInfo();

    if (_isUpiFlow) {
      _loadQrCode(_initialPaymentAmount);
    }

    _refreshPaymentMethods();

    _paymentMethodsPollTimer = Timer.periodic(
      const Duration(seconds: 6),
          (_) => _refreshPaymentMethods(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Initial amount
  // ─────────────────────────────────────────────────────────────

  double get _initialPaymentAmount {
    if (_finalTotal > 0) {
      return _finalTotal;
    }

    return 0;
  }

  // ─────────────────────────────────────────────────────────────
  // Refresh payment methods
  // ─────────────────────────────────────────────────────────────

  Future<void> _refreshPaymentMethods() async {
    try {
      await StoreProfileCache.preload(forceRefresh: true);

      if (!mounted) return;

      final fresh = StoreProfileCache.paymentMethods;

      final unchanged =
          fresh.length == _paymentMethods.length &&
              fresh.every(
                    (m) => _paymentMethods.any(
                      (existing) =>
                  existing['name'].toString() ==
                      m['name'].toString(),
                ),
              );

      if (unchanged) return;

      setState(() {
        _paymentMethods = fresh;

        final stillValid = fresh.any(
              (m) =>
          m['name'].toString() ==
              _selectedPayment,
        );

        if (!stillValid) {
          _selectedPayment = fresh.isNotEmpty
              ? fresh.first['name'].toString()
              : '';

          _qrImageUrl = '';
          _qrError = '';
        }
      });

      if (_isUpiFlow &&
          _qrImageUrl.isEmpty &&
          !_qrLoading) {
        await _loadQrCode(_initialPaymentAmount);
      }
    } catch (_) {
      // Keep existing payment methods if refresh fails.
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Load store UPI + wallet
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadCustomerPaymentInfo() async {
    try {
      final result =
      await ProfileGetApiService.getProfile();

      if (!mounted) return;

      if (result['success'] == true) {
        final data =
        result['data'] as Map<String, dynamic>;

        final upiNumber = data['upi']?.toString().trim() ?? '';

        final wallet =
            double.tryParse(
              data['wallet_amount']?.toString() ?? '',
            ) ??
                0;

        final upiName =
            data['upi_name']?.toString().trim() ??
                data['store_name']?.toString().trim() ??
                data['name']?.toString().trim() ??
                'Store';

        setState(() {
          _storeUpiId = upiNumber;
          _storeUpiName =
          upiName.isNotEmpty ? upiName : 'Store';
          _walletBalance = wallet;
        });
      }
    } catch (_) {
      // Do nothing. UI will show unavailable UPI.
    }
  }

  // ─────────────────────────────────────────────────────────────
  // QR
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadQrCode(double amount) async {
    if (amount <= 0) return;

    if (mounted) {
      setState(() {
        _qrLoading = true;
        _qrError = '';
      });
    }

    try {
      final token =
          await SessionManager.getToken() ?? '';

      final result =
      await UpiQrService.generateQr(
        token: token,
        amount: amount,
      );

      if (!mounted) return;

      setState(() {
        _qrLoading = false;

        if (result.success &&
            result.qrImageUrl.isNotEmpty) {
          _qrImageUrl = result.qrImageUrl;
        } else {
          _qrError = result.error.isNotEmpty
              ? result.error
              : 'Could not generate QR code';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _qrLoading = false;
        _qrError =
        'Could not generate QR code';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _paymentMethodsPollTimer?.cancel();
    _couponController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Payment helpers
  // ─────────────────────────────────────────────────────────────

  String get _paymentLabel => _selectedPayment;

  bool get _isUpiFlow =>
      _selectedPayment.toUpperCase().contains('UPI');

  String get _paymentApiValue => _selectedPayment;

  bool get _isPlaceOrderEnabled {
    if (_paymentMethods.isEmpty) {
      return false;
    }

    if (_isUpiFlow) {
      return _storeUpiId.isNotEmpty &&
          !_upiLoading;
    }

    return true;
  }

  // ─────────────────────────────────────────────────────────────
  // Coupon
  // ─────────────────────────────────────────────────────────────

  Future<void> _applyCoupon(double cartTotal) async {
    final code =
    _couponController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _couponError =
        'Please enter a coupon code';
      });
      return;
    }

    setState(() {
      _couponLoading = true;
      _couponError = '';
    });

    final token =
        await SessionManager.getToken() ?? '';

    final result =
    await CouponApiService.applyCoupon(
      token: token,
      couponCode: code,
      grandTotal: cartTotal,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _couponError = result.error;
        _couponLoading = false;
      });
      return;
    }

    final coupon = result.coupon!;

    _applySuccess(
      coupon.code,
      coupon.discountAmount,
    );
  }

  void _applySuccess(
      String code,
      double discount,
      ) {
    setState(() {
      _couponApplied = true;
      _couponCode = code;
      _couponDiscount =
          double.parse(
            discount.toStringAsFixed(0),
          );
      _couponLoading = false;
      _couponError = '';
    });
  }

  void _removeCoupon() {
    setState(() {
      _couponApplied = false;
      _couponCode = '';
      _couponDiscount = 0.0;
      _couponError = '';
      _couponController.clear();
    });
  }

  Future<void> _openAllCoupons(
      double cartTotal,
      ) async {
    setState(() => _couponLoading = true);

    final token =
        await SessionManager.getToken() ?? '';

    final result =
    await CouponApiService.getCoupons(
      token: token,
    );

    if (!mounted) return;

    setState(() => _couponLoading = false);

    if (!result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty
                ? result.message
                : 'Could not load coupons',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selected =
    await Navigator.push<CouponModel>(
      context,
      MaterialPageRoute(
        builder: (_) => _AllCouponsScreen(
          coupons: result.coupons,
          cartTotal: cartTotal,
          token: token,
        ),
      ),
    );

    if (selected != null) {
      _couponController.text =
          selected.code;

      _applySuccess(
        selected.code,
        selected.discountAmount,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Wallet
  // ─────────────────────────────────────────────────────────────

  double _walletApplied(double grandTotal) {
    if (!_useWallet) return 0;

    return _walletBalance < grandTotal
        ? _walletBalance
        : grandTotal;
  }

  double _payableAmount(double grandTotal) {
    final payable =
        grandTotal -
            _walletApplied(grandTotal);

    return payable < 0 ? 0 : payable;
  }

  // ─────────────────────────────────────────────────────────────
  // UPI PAYMENT
  // ─────────────────────────────────────────────────────────────

  Future<UpiPaymentResult?> _startUpiPayment(
      double payableAmount,
      ) async {
    if (_storeUpiId.isEmpty) {
      _showToast(
        context,
        'Store UPI ID is not available.',
      );
      return null;
    }

    if (payableAmount <= 0) {
      _showToast(
        context,
        'No UPI payment is required.',
      );
      return null;
    }

    final transactionId =
        'TXN_${DateTime.now().microsecondsSinceEpoch}';

    final transactionRefId =
        'ORDER_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _upiLoading = true;
      _placingOrder = true;
    });

    try {
      final result =
      await EasyUpiPaymentService.instance
          .makePayment(
        payeeVpa: _storeUpiId,
        payeeName: _storeUpiName,
        amount: payableAmount,
        transactionId: transactionId,
        transactionRefId: transactionRefId,
        description: 'Food Order Payment',
      );

      if (!mounted) return result;

      setState(() {
        _upiLoading = false;
      });

      _lastTransactionId =
          result.transactionId;

      _lastTransactionRefId =
          result.transactionRefId;

      _lastApprovalRefNo =
          result.approvalRefNo;

      _lastResponseCode =
          result.responseCode;

      _lastPaymentAmount =
          result.amount;

      if (!result.success) {
        setState(() {
          _placingOrder = false;
        });

        _showToast(
          context,
          result.responseCode.isEmpty
              ? 'UPI payment was cancelled or failed.'
              : 'UPI payment failed. Response code: ${result.responseCode}',
        );

        return null;
      }

      return result;
    } catch (e) {
      if (!mounted) return null;

      setState(() {
        _upiLoading = false;
        _placingOrder = false;
      });

      _showToast(
        context,
        'Unable to open UPI payment app. Please try again.',
      );

      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PLACE ORDER
  // ─────────────────────────────────────────────────────────────

  Future<void> _placeOrder(
      BuildContext context,
      CartModel cart,
      ) async {
    if (_defaultAddress == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a delivery address first',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final stillEnabled =
    _paymentMethods.any(
          (m) =>
      m['name'].toString() ==
          _selectedPayment,
    );

    if (!stillEnabled) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'This payment method is no longer available. Please choose another.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      await _refreshPaymentMethods();
      return;
    }

    // Recalculate the exact amount from current cart.
    final cartSubTotalNow =
        cart.totalPrice;

    final grandTotalNow =
        cartSubTotalNow +
            _deliveryFee -
            _couponDiscount;

    final walletUsedNow =
    _walletApplied(grandTotalNow);

    final payableAmountNow =
    _payableAmount(grandTotalNow);

    // ─────────────────────────────────────────
    // Confirm order
    // ─────────────────────────────────────────

    final confirmed =
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              color:
              AppColors.buttonPrimary,
              size: 24,
            ),
            SizedBox(width: 10),
            Text(
              'Confirm Order',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize:
          MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to place this order?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(12),
              decoration:
              BoxDecoration(
                color: AppColors
                    .buttonPrimary
                    .withOpacity(0.05),
                borderRadius:
                BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors
                      .buttonPrimary
                      .withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      Text(
                        'Payment',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Colors.grey[600],
                        ),
                      ),
                      Text(
                        _paymentLabel,
                        style:
                        const TextStyle(
                          fontSize: 12,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Colors.grey[600],
                        ),
                      ),
                      Text(
                        '₹${payableAmountNow.toStringAsFixed(2)}',
                        style:
                        const TextStyle(
                          fontSize: 13,
                          fontWeight:
                          FontWeight.bold,
                          color: AppColors
                              .success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      Text(
                        'Deliver to',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Colors.grey[600],
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _defaultAddress
                              ?.fullName ??
                              '',
                          textAlign:
                          TextAlign.right,
                          style:
                          const TextStyle(
                            fontSize: 12,
                            fontWeight:
                            FontWeight.bold,
                          ),
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
            onPressed: () =>
                Navigator.pop(
                  context,
                  false,
                ),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.black54,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(
                  context,
                  true,
                ),
            style:
            ElevatedButton.styleFrom(
              backgroundColor:
              AppColors
                  .buttonPrimary,
            ),
            child: const Text(
              'CONFIRM',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    // ─────────────────────────────────────────
    // UPI PAYMENT FIRST
    // ─────────────────────────────────────────

    UpiPaymentResult? upiResult;

    if (_isUpiFlow) {
      upiResult =
      await _startUpiPayment(
        payableAmountNow,
      );

      if (!mounted) return;

      if (upiResult == null) {
        setState(() {
          _placingOrder = false;
        });
        return;
      }

      // IMPORTANT:
      // Do not continue if UPI did not return success.
      if (!upiResult.success) {
        setState(() {
          _placingOrder = false;
        });
        return;
      }
    }

    // ─────────────────────────────────────────
    // PLACE ORDER
    // ─────────────────────────────────────────

    try {
      setState(() {
        _placingOrder = true;
      });

      final result =
      await OrderApiService.placeOrder(
        cart: cart,
        address: _defaultAddress!,
        paymentMethod:
        _paymentApiValue,
        couponCode:
        _couponApplied
            ? _couponCode
            : '',
        couponDiscount:
        _couponApplied
            ? _couponDiscount
            : 0.0,
        deliveryCharge:
        _deliveryFee,

        // New UPI transaction fields.
        transactionId:
        _isUpiFlow
            ? (upiResult
            ?.transactionId ??
            '')
            : '',
        transactionRefId:
        _isUpiFlow
            ? (upiResult
            ?.transactionRefId ??
            '')
            : '',
        approvalRefNo:
        _isUpiFlow
            ? (upiResult
            ?.approvalRefNo ??
            '')
            : '',
        responseCode:
        _isUpiFlow
            ? (upiResult
            ?.responseCode ??
            '')
            : '',
        paymentAmount:
        _isUpiFlow
            ? payableAmountNow
            : 0,

        walletAmountUsed:
        walletUsedNow,
      );

      if (!mounted) return;

      setState(() {
        _placingOrder = false;
        _upiLoading = false;
      });

      final isSuccess =
          result['status']
              ?.toString()
              .toLowerCase() ==
              'success';

      final orderId =
          result['order_id']
              ?.toString() ??
              '';

      if (isSuccess) {
        final purchasedItems =
        cart.items.values.toList();

        final cartSubTotal =
            cart.totalPrice;

        final total =
            cartSubTotal +
                _deliveryFee -
                _couponDiscount -
                walletUsedNow;

        cart.clearCart();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (nc) =>
                _OrderSuccessScreen(
                  orderId: orderId,
                  total: total,
                  paymentLabel:
                  _paymentLabel,
                  address:
                  _defaultAddress!,
                  purchasedItems:
                  purchasedItems,
                  deliveryFee:
                  _deliveryFee,
                  subTotal:
                  cartSubTotal,
                  transactionId:
                  _isUpiFlow
                      ? _lastTransactionId
                      : '',
                  onContinue: () async {
                    final token =
                        await SessionManager
                            .getToken() ??
                            '';

                    final customerId =
                        await SessionManager
                            .getCustomerId() ??
                            '';

                    final telephone =
                        await SessionManager
                            .getTelephone() ??
                            '';

                    if (!nc.mounted) return;

                    Navigator.of(nc)
                        .pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) =>
                            HomeScreen(
                              authToken: token,
                              customerId:
                              customerId,
                              telephone:
                              telephone,
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
        _showToast(
          context,
          _cleanMessage(
            result['message']
                ?.toString() ??
                'Order could not be placed. Please try again.',
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _placingOrder = false;
        _upiLoading = false;
      });

      _showToast(
        context,
        'Network error. Please try again.',
      );
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final maxContentWidth =
    screenWidth > 900
        ? 720.0
        : screenWidth > 600
        ? 560.0
        : double.infinity;

    final horizontalPad =
    screenWidth > 600
        ? 32.0
        : 24.0;

    return Scaffold(
      backgroundColor:
      AppColors.white,
      appBar: AppBar(
        backgroundColor:
        AppColors.appBarBg,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color:
            AppColors.appBarIcon,
          ),
          onPressed: () =>
              Navigator.pop(context),
        ),
        title: const Text(
          'Payment Method',
          style: TextStyle(
            color:
            AppColors.appBarText,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<CartModel>(
        builder: (
            context,
            cart,
            _,
            ) {
          final baseTotal =
              cart.totalPrice +
                  _deliveryFee;

          final grandTotal =
              baseTotal -
                  _couponDiscount;

          if (_useWallet &&
              _walletBalance <
                  grandTotal) {
            WidgetsBinding.instance
                .addPostFrameCallback(
                  (_) {
                if (mounted) {
                  setState(() {
                    _useWallet = false;
                  });
                }
              },
            );
          }

          final payableAmount =
          _payableAmount(
            grandTotal,
          );

          return Column(
            children: [
              Expanded(
                child:
                SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(
                        maxWidth:
                        maxContentWidth,
                      ),
                      child: Padding(
                        padding:
                        EdgeInsets.symmetric(
                          horizontal:
                          horizontalPad,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            // ─────────────────────────────
                            // ADDRESS
                            // ─────────────────────────────

                            if (_addrLoading)
                              const Padding(
                                padding:
                                EdgeInsets.only(
                                  bottom: 24,
                                ),
                                child:
                                LinearProgressIndicator(),
                              )
                            else if (_defaultAddress !=
                                null) ...[
                              const Text(
                                'Delivery Address',
                                style:
                                TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              Container(
                                padding:
                                const EdgeInsets
                                    .all(16),
                                decoration:
                                BoxDecoration(
                                  color: AppColors
                                      .successLight,
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                      12),
                                  border:
                                  Border.all(
                                    color: AppColors
                                        .success
                                        .withOpacity(
                                        0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                                  children: [
                                    Container(
                                      padding:
                                      const EdgeInsets
                                          .all(8),
                                      decoration:
                                      BoxDecoration(
                                        color: AppColors
                                            .success
                                            .withOpacity(
                                            0.12),
                                        shape:
                                        BoxShape
                                            .circle,
                                      ),
                                      child:
                                      const Icon(
                                        Icons
                                            .location_on,
                                        color:
                                        AppColors
                                            .success,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 12,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(
                                            _defaultAddress!
                                                .fullName,
                                            style:
                                            const TextStyle(
                                              fontSize:
                                              15,
                                              fontWeight:
                                              FontWeight
                                                  .bold,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 5,
                                          ),
                                          Text(
                                            _defaultAddress!
                                                .singleLine,
                                            style:
                                            TextStyle(
                                              fontSize:
                                              13,
                                              color: Colors
                                                  .grey[700],
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 4,
                                          ),
                                          Text(
                                            _defaultAddress!
                                                .phone,
                                            style:
                                            TextStyle(
                                              fontSize:
                                              13,
                                              color: Colors
                                                  .grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 24,
                              ),
                            ] else ...[
                              Container(
                                padding:
                                const EdgeInsets
                                    .all(14),
                                decoration:
                                BoxDecoration(
                                  color:
                                  Colors.orange[50],
                                  borderRadius:
                                  BorderRadius
                                      .circular(8),
                                  border:
                                  Border.all(
                                    color:
                                    Colors.orange[
                                    300]!,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons
                                          .warning_amber_rounded,
                                    ),
                                    SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      child:
                                      Text(
                                        'No delivery address selected. Please go back and select an address.',
                                        style:
                                        TextStyle(
                                          fontSize:
                                          13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 24,
                              ),
                            ],

                            // ─────────────────────────────
                            // PAYMENT METHODS
                            // ─────────────────────────────

                            const Text(
                              'Select Payment Method',
                              style:
                              TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 16,
                            ),

                            if (_paymentMethods
                                .isEmpty)
                              Container(
                                padding:
                                const EdgeInsets
                                    .all(14),
                                decoration:
                                BoxDecoration(
                                  color:
                                  Colors.orange[
                                  50],
                                  borderRadius:
                                  BorderRadius
                                      .circular(8),
                                ),
                                child: const Text(
                                  'No payment methods are currently enabled by the store.',
                                ),
                              )
                            else
                              ...List.generate(
                                _paymentMethods
                                    .length,
                                    (i) {
                                  final m =
                                  _paymentMethods[
                                  i];

                                  final name =
                                  m['name']
                                      .toString();

                                  final isUpi =
                                  name
                                      .toUpperCase()
                                      .contains(
                                      'UPI');

                                  return Column(
                                    children: [
                                      _paymentOption(
                                        name,
                                        name,
                                        isUpi
                                            ? 'Pay securely using Google Pay, PhonePe, Paytm & other UPI apps'
                                            : 'Pay when you receive the order',
                                      ),
                                      if (i !=
                                          _paymentMethods
                                              .length -
                                              1)
                                        const Divider(),
                                    ],
                                  );
                                },
                              ),

                            // ─────────────────────────────
                            // UPI
                            // ─────────────────────────────

                            if (_isUpiFlow)
                              _buildUpiSection(
                                payableAmount,
                              ),

                            const SizedBox(
                              height: 24,
                            ),

                            // ─────────────────────────────
                            // WALLET
                            // ─────────────────────────────

                            if (_walletBalance >
                                0) ...[
                              _buildWalletSection(
                                grandTotal,
                              ),
                              const SizedBox(
                                height: 24,
                              ),
                            ],

                            // ─────────────────────────────
                            // COUPON
                            // ─────────────────────────────

                            _buildCouponSection(
                              cart.totalPrice,
                            ),

                            const SizedBox(
                              height: 24,
                            ),

                            // ─────────────────────────────
                            // SUMMARY
                            // ─────────────────────────────

                            const Text(
                              'Order Summary',
                              style:
                              TextStyle(
                                fontSize: 16,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),

                            Container(
                              padding:
                              const EdgeInsets
                                  .all(14),
                              decoration:
                              BoxDecoration(
                                color:
                                const Color(
                                    0xFFF8F8F8),
                                borderRadius:
                                BorderRadius
                                    .circular(8),
                              ),
                              child: Column(
                                children: [
                                  _summaryRow(
                                    'Items',
                                    '${cart.items.length} product(s)',
                                  ),
                                  const SizedBox(
                                    height: 6,
                                  ),
                                  _summaryRow(
                                    'Sub Total',
                                    '₹${cart.totalPrice.toStringAsFixed(0)}',
                                  ),
                                  const SizedBox(
                                    height: 6,
                                  ),
                                  _summaryRow(
                                    'Delivery',
                                    _deliveryFee ==
                                        0
                                        ? 'FREE'
                                        : '₹${_deliveryFee.toStringAsFixed(0)}',
                                    valueColor:
                                    _deliveryFee ==
                                        0
                                        ? AppColors
                                        .success
                                        : AppColors
                                        .textDark,
                                  ),
                                  if (_couponApplied) ...[
                                    const SizedBox(
                                      height: 6,
                                    ),
                                    _summaryRow(
                                      'Coupon ($_couponCode)',
                                      '- ₹${_couponDiscount.toStringAsFixed(0)}',
                                      valueColor:
                                      AppColors
                                          .success,
                                    ),
                                  ],
                                  if (_useWallet &&
                                      _walletApplied(
                                          grandTotal) >
                                          0) ...[
                                    const SizedBox(
                                      height: 6,
                                    ),
                                    _summaryRow(
                                      'Wallet Applied',
                                      '- ₹${_walletApplied(grandTotal).toStringAsFixed(0)}',
                                      valueColor:
                                      AppColors
                                          .success,
                                    ),
                                  ],
                                  const Divider(
                                    height: 16,
                                  ),
                                  _summaryRow(
                                    'Payable Amount',
                                    '₹${payableAmount.toStringAsFixed(2)}',
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ─────────────────────────────────────
              // BOTTOM BUTTON
              // ─────────────────────────────────────

              Container(
                decoration:
                BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.1),
                      blurRadius: 10,
                      offset:
                      const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(
                        maxWidth:
                        maxContentWidth,
                      ),
                      child: Padding(
                        padding:
                        EdgeInsets.symmetric(
                          horizontal:
                          horizontalPad,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount:',
                                  style:
                                  TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '₹${payableAmount.toStringAsFixed(2)}',
                                  style:
                                  const TextStyle(
                                    fontSize: 22,
                                    fontWeight:
                                    FontWeight.bold,
                                    color:
                                    AppColors
                                        .textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            SizedBox(
                              width:
                              double.infinity,
                              child:
                              ElevatedButton(
                                onPressed:
                                (_placingOrder ||
                                    !_isPlaceOrderEnabled)
                                    ? null
                                    : () =>
                                    _placeOrder(
                                      context,
                                      cart,
                                    ),
                                style:
                                ElevatedButton
                                    .styleFrom(
                                  backgroundColor:
                                  AppColors
                                      .buttonPrimary,
                                  disabledBackgroundColor:
                                  AppColors
                                      .buttonPrimaryDisabled,
                                  padding:
                                  const EdgeInsets
                                      .symmetric(
                                    vertical: 16,
                                  ),
                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                        12),
                                  ),
                                ),
                                child:
                                _placingOrder
                                    ? const SizedBox(
                                  height:
                                  22,
                                  width:
                                  22,
                                  child:
                                  CircularProgressIndicator(
                                    color: Colors
                                        .white,
                                    strokeWidth:
                                    2.5,
                                  ),
                                )
                                    : Text(
                                  _isUpiFlow
                                      ? 'PAY ₹${payableAmount.toStringAsFixed(2)} VIA UPI'
                                      : 'PLACE ORDER',
                                  style:
                                  const TextStyle(
                                    color:
                                    Colors.white,
                                    fontSize:
                                    15,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UPI SECTION
  // ─────────────────────────────────────────────

  Widget _buildUpiSection(
      double payableAmount,
      ) {
    return Container(
      margin:
      const EdgeInsets.only(
        top: 8,
        bottom: 8,
      ),
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color: AppColors
            .primaryBlue
            .withOpacity(0.05),
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: AppColors
              .primaryBlue
              .withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _stepLabel(
            '1',
            'Pay using UPI App',
          ),
          const SizedBox(
            height: 10,
          ),

          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(14),
            decoration:
            BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey[300]!,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 36,
                  color:
                  AppColors.buttonPrimary,
                ),
                const SizedBox(
                  height: 8,
                ),
                const Text(
                  'Amount to Pay',
                  style:
                  TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  '₹${payableAmount.toStringAsFixed(2)}',
                  style:
                  const TextStyle(
                    fontSize: 26,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    AppColors.success,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  _storeUpiId.isNotEmpty
                      ? 'Pay to $_storeUpiName'
                      : 'UPI details loading...',
                  textAlign:
                  TextAlign.center,
                  style:
                  TextStyle(
                    fontSize: 12,
                    color:
                    Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
              (_upiLoading ||
                  _storeUpiId
                      .isEmpty ||
                  payableAmount <= 0)
                  ? null
                  : () async {
                await _startUpiPayment(
                  payableAmount,
                );
              },
              icon: _upiLoading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child:
                CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons
                    .account_balance_wallet,
                color: Colors.white,
              ),
              label: Text(
                _upiLoading
                    ? 'OPENING UPI APP...'
                    : 'PAY ₹${payableAmount.toStringAsFixed(2)} VIA UPI APP',
                style:
                const TextStyle(
                  color: Colors.white,
                  fontWeight:
                  FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.buttonPrimary,
                disabledBackgroundColor:
                AppColors
                    .buttonPrimaryDisabled,
                padding:
                const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                      10),
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Row(
            children: [
              const Icon(
                Icons.lock_outline,
                size: 14,
                color: Colors.green,
              ),
              const SizedBox(
                width: 5,
              ),
              Expanded(
                child: Text(
                  'The exact amount above will be sent to your selected UPI app.',
                  style:
                  TextStyle(
                    fontSize: 11,
                    color:
                    Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          const Divider(),

          const SizedBox(
            height: 10,
          ),

          // QR fallback
          _stepLabel(
            '2',
            'Or Scan QR Code',
          ),

          const SizedBox(
            height: 8,
          ),

          if (_qrLoading)
            const Padding(
              padding:
              EdgeInsets.symmetric(
                vertical: 12,
              ),
              child:
              LinearProgressIndicator(
                color:
                AppColors.buttonPrimary,
              ),
            )
          else if (_qrError.isNotEmpty)
            Container(
              padding:
              const EdgeInsets.all(10),
              decoration:
              BoxDecoration(
                color:
                Colors.red[50],
                borderRadius:
                BorderRadius.circular(
                    8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _qrError,
                      style:
                      TextStyle(
                        fontSize: 12,
                        color:
                        Colors.red[700],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        _loadQrCode(
                          payableAmount,
                        ),
                    child:
                    const Text(
                      'Retry',
                    ),
                  ),
                ],
              ),
            )
          else if (_qrImageUrl.isNotEmpty)
              Center(
                child: Container(
                  padding:
                  const EdgeInsets.all(
                      12),
                  decoration:
                  BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(
                        12),
                    border: Border.all(
                      color: Colors.grey[
                      300]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Image.network(
                        _qrImageUrl,
                        width: 210,
                        height: 210,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) =>
                        const SizedBox(
                          width: 210,
                          height: 210,
                          child: Center(
                            child: Icon(
                              Icons
                                  .qr_code_2,
                              size: 60,
                              color:
                              Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        '₹${payableAmount.toStringAsFixed(2)}',
                        style:
                        const TextStyle(
                          fontSize: 18,
                          fontWeight:
                          FontWeight.bold,
                          color:
                          AppColors
                              .success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'You can also scan this QR code with any UPI app.',
            style:
            TextStyle(
              fontSize: 11,
              color:
              Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PAYMENT OPTION
  // ─────────────────────────────────────────────

  Widget _paymentOption(
      String value,
      String title,
      String subtitle,
      ) {
    return RadioListTile<String>(
      value: value,
      groupValue:
      _selectedPayment,
      onChanged: (v) {
        if (v == null) return;

        setState(() {
          _selectedPayment = v;
          _qrImageUrl = '';
          _qrError = '';
        });

        if (v.toUpperCase().contains('UPI')) {
          _loadQrCode(
            _initialPaymentAmount,
          );
        }
      },
      activeColor:
      AppColors.buttonPrimary,
      title: Text(
        title,
        style:
        const TextStyle(
          fontSize: 16,
          fontWeight:
          FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style:
        const TextStyle(
          fontSize: 14,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STEP LABEL
  // ─────────────────────────────────────────────

  Widget _stepLabel(
      String number,
      String label,
      ) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment:
          Alignment.center,
          decoration:
          const BoxDecoration(
            color:
            AppColors.floatingCartBg,
            shape:
            BoxShape.circle,
          ),
          child: Text(
            number,
            style:
            const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(
          width: 8,
        ),
        Expanded(
          child: Text(
            label,
            style:
            const TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // WALLET
  // ─────────────────────────────────────────────

  Widget _buildWalletSection(
      double grandTotal,
      ) {
    final applied =
    _walletApplied(grandTotal);

    return Container(
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: _useWallet
              ? Colors.green
              .withOpacity(0.5)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding:
            const EdgeInsets.all(8),
            decoration:
            BoxDecoration(
              color: AppColors
                  .floatingCartBg
                  .withOpacity(0.08),
              borderRadius:
              BorderRadius.circular(
                  8),
            ),
            child: const Icon(
              Icons
                  .account_balance_wallet_outlined,
              color:
              AppColors
                  .floatingCartBg,
              size: 20,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Use Wallet Balance',
                  style:
                  TextStyle(
                    fontSize: 14,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  _useWallet
                      ? 'Applying ₹${applied.toStringAsFixed(0)}'
                      : 'Available: ₹${_walletBalance.toStringAsFixed(0)}',
                  style:
                  TextStyle(
                    fontSize: 12,
                    color:
                    Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _useWallet,
            activeColor:
            AppColors.buttonPrimary,
            onChanged: (v) {
              if (v &&
                  _walletBalance <
                      grandTotal) {
                _showToast(
                  context,
                  'Wallet balance is less than the order total.',
                );
                return;
              }

              setState(() {
                _useWallet = v;
              });
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // COUPON
  // ─────────────────────────────────────────────

  Widget _buildCouponSection(
      double cartTotal,
      ) {
    return Container(
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: _couponApplied
              ? Colors.green
              .withOpacity(0.5)
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              10,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .local_offer_outlined,
                  color:
                  AppColors
                      .floatingCartBg,
                ),
                const SizedBox(
                  width: 10,
                ),
                const Text(
                  'Apply Coupon',
                  style:
                  TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_couponApplied)
                  const Text(
                    'APPLIED',
                    style:
                    TextStyle(
                      color: Colors.green,
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(
            height: 1,
          ),
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              14,
            ),
            child: _couponApplied
                ? _buildAppliedCoupon()
                : _buildCouponInput(
              cartTotal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponInput(
      double cartTotal,
      ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child:
              TextFormField(
                controller:
                _couponController,
                textCapitalization:
                TextCapitalization
                    .characters,
                decoration:
                InputDecoration(
                  hintText:
                  'Enter coupon code',
                  filled: true,
                  fillColor:
                  const Color(
                      0xFFF8F8F8),
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                        10),
                  ),
                ),
                onChanged: (_) {
                  if (_couponError
                      .isNotEmpty) {
                    setState(() {
                      _couponError =
                      '';
                    });
                  }
                },
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            ElevatedButton(
              onPressed:
              _couponLoading
                  ? null
                  : () =>
                  _applyCoupon(
                    cartTotal,
                  ),
              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                AppColors
                    .buttonPrimary,
              ),
              child:
              _couponLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(
                  color:
                  Colors.white,
                  strokeWidth:
                  2,
                ),
              )
                  : const Text(
                'APPLY',
                style:
                TextStyle(
                  color:
                  Colors.white,
                  fontWeight:
                  FontWeight
                      .bold,
                ),
              ),
            ),
          ],
        ),
        if (_couponError
            .isNotEmpty) ...[
          const SizedBox(
            height: 8,
          ),
          Align(
            alignment:
            Alignment.centerLeft,
            child: Text(
              _couponError,
              style:
              const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(
          height: 8,
        ),
        Align(
          alignment:
          Alignment.centerLeft,
          child: TextButton(
            onPressed:
            _couponLoading
                ? null
                : () =>
                _openAllCoupons(
                  cartTotal,
                ),
            child: const Text(
              'View all coupons',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppliedCoupon() {
    return Row(
      children: [
        const Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Text(
                _couponCode,
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              Text(
                'You save ₹${_couponDiscount.toStringAsFixed(0)}',
                style:
                const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed:
          _removeCoupon,
          child: const Text(
            'Remove',
            style:
            TextStyle(
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SUMMARY
  // ─────────────────────────────────────────────

  Widget _summaryRow(
      String label,
      String value, {
        Color? valueColor,
        bool bold = false,
      }) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment
          .spaceBetween,
      children: [
        Text(
          label,
          style:
          TextStyle(
            fontSize: 14,
            color: bold
                ? Colors.black
                : Colors.grey[700],
            fontWeight: bold
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style:
          TextStyle(
            fontSize: 14,
            fontWeight: bold
                ? FontWeight.bold
                : FontWeight.w500,
            color: valueColor ??
                (bold
                    ? Colors.black
                    : Colors.black87),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // TOAST
  // ─────────────────────────────────────────────

  void _showToast(
      BuildContext context,
      String message,
      ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                message,
                style:
                const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
        Colors.red[600],
        behavior:
        SnackBarBehavior.floating,
        margin:
        const EdgeInsets.all(12),
        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(
              10),
        ),
      ),
    );
  }

  String _cleanMessage(
      String msg,
      ) {
    if (msg.contains('/home/') ||
        msg.contains('.php') ||
        msg.length > 150) {
      return 'Order could not be placed. Please try again.';
    }

    return msg;
  }
}

// ═══════════════════════════════════════════════════════════════
// ALL COUPONS
// ═══════════════════════════════════════════════════════════════

class _AllCouponsScreen
    extends StatefulWidget {
  final List<CouponModel> coupons;
  final double cartTotal;
  final String token;

  const _AllCouponsScreen({
    required this.coupons,
    required this.cartTotal,
    required this.token,
  });

  @override
  State<_AllCouponsScreen> createState() =>
      _AllCouponsScreenState();
}

class _AllCouponsScreenState
    extends State<_AllCouponsScreen> {
  String? _applyingCode;

  Future<void> _applyCoupon(
      CouponModel coupon,
      ) async {
    setState(() {
      _applyingCode =
          coupon.code;
    });

    final result =
    await CouponApiService
        .applyCoupon(
      token: widget.token,
      couponCode:
      coupon.code,
      grandTotal:
      widget.cartTotal,
    );

    if (!mounted) return;

    setState(() {
      _applyingCode = null;
    });

    if (!result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            result.error.isNotEmpty
                ? result.error
                : 'Could not apply coupon',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      result.coupon,
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final cartTotal =
        widget.cartTotal;

    final coupons =
        widget.coupons;

    final eligible = coupons
        .where(
          (c) =>
          c.isEligible(cartTotal),
    )
        .toList();

    final blocked = coupons
        .where(
          (c) =>
      !c.isEligible(cartTotal),
    )
        .toList();

    final sorted = [
      ...eligible,
      ...blocked,
    ];

    return Scaffold(
      backgroundColor:
      AppColors.white,
      appBar: AppBar(
        backgroundColor:
        AppColors.appBarBg,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color:
            AppColors.appBarIcon,
          ),
          onPressed: () =>
              Navigator.pop(context),
        ),
        title: const Text(
          'Available Coupons',
          style:
          TextStyle(
            color:
            AppColors.appBarText,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
            const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .shopping_cart_outlined,
                  size: 16,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  'Your cart total: ₹${cartTotal.toStringAsFixed(0)}',
                  style:
                  const TextStyle(
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (eligible.isNotEmpty)
                  Text(
                    '${eligible.length} applicable',
                    style:
                    const TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          if (coupons.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No coupons available',
                ),
              ),
            )
          else
            Expanded(
              child:
              ListView.builder(
                padding:
                const EdgeInsets.all(
                    16),
                itemCount:
                sorted.length,
                itemBuilder:
                    (context, index) {
                  final coupon =
                  sorted[index];

                  final isEligible =
                  coupon.isEligible(
                      cartTotal);

                  final discount =
                  coupon.computeDiscount(
                      cartTotal);

                  return _CouponCard(
                    coupon: coupon,
                    isEligible:
                    isEligible,
                    discount:
                    discount,
                    cartTotal:
                    cartTotal,
                    isApplying:
                    _applyingCode ==
                        coupon.code,
                    onTap:
                    isEligible &&
                        _applyingCode ==
                            null
                        ? () =>
                        _applyCoupon(
                          coupon,
                        )
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COUPON CARD
// ═══════════════════════════════════════════════════════════════

class _CouponCard
    extends StatelessWidget {
  final CouponModel coupon;
  final bool isEligible;
  final double discount;
  final double cartTotal;
  final bool isApplying;
  final VoidCallback? onTap;

  const _CouponCard({
    required this.coupon,
    required this.isEligible,
    required this.discount,
    required this.cartTotal,
    required this.isApplying,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Opacity(
      opacity:
      isEligible ? 1 : 0.55,
      child: Container(
        margin:
        const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
        const EdgeInsets.all(16),
        decoration:
        BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(12),
          border: Border.all(
            color: isEligible
                ? AppColors
                .floatingCartBg
                : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration:
                  BoxDecoration(
                    color: isEligible
                        ? AppColors
                        .floatingCartBg
                        : Colors.grey,
                    borderRadius:
                    BorderRadius
                        .circular(6),
                  ),
                  child: Text(
                    coupon.code,
                    style:
                    const TextStyle(
                      color:
                      Colors.white,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  coupon.title,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              coupon.description,
              style:
              const TextStyle(
                fontSize: 13,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            if (isEligible)
              SizedBox(
                width:
                double.infinity,
                child:
                ElevatedButton(
                  onPressed:
                  isApplying
                      ? null
                      : onTap,
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    AppColors
                        .buttonPrimary,
                  ),
                  child:
                  isApplying
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      color:
                      Colors.white,
                      strokeWidth:
                      2,
                    ),
                  )
                      : Text(
                    'Apply • Save ₹${discount.toStringAsFixed(0)}',
                    style:
                    const TextStyle(
                      color:
                      Colors.white,
                      fontWeight:
                      FontWeight
                          .bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ORDER SUCCESS
// ═══════════════════════════════════════════════════════════════

class _OrderSuccessScreen
    extends StatelessWidget {
  final String orderId;
  final double total;
  final String paymentLabel;
  final AddressModel address;
  final List<CartItem> purchasedItems;
  final VoidCallback onContinue;
  final double deliveryFee;
  final double subTotal;
  final String transactionId;

  const _OrderSuccessScreen({
    required this.orderId,
    required this.total,
    required this.paymentLabel,
    required this.address,
    required this.purchasedItems,
    required this.onContinue,
    required this.deliveryFee,
    required this.subTotal,
    this.transactionId = '',
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final maxContentWidth =
    screenWidth > 900
        ? 720.0
        : screenWidth > 600
        ? 560.0
        : double.infinity;

    final horizontalPad =
    screenWidth > 600
        ? 32.0
        : 20.0;

    return Scaffold(
      backgroundColor:
      Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
              SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                    BoxConstraints(
                      maxWidth:
                      maxContentWidth,
                    ),
                    child: Padding(
                      padding:
                      EdgeInsets.fromLTRB(
                        horizontalPad,
                        36,
                        horizontalPad,
                        20,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding:
                            const EdgeInsets
                                .all(24),
                            decoration:
                            const BoxDecoration(
                              color: AppColors
                                  .successLight,
                              shape:
                              BoxShape.circle,
                            ),
                            child:
                            const Icon(
                              Icons
                                  .check_circle,
                              color: AppColors
                                  .success,
                              size: 80,
                            ),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          const Text(
                            'Order Placed\nSuccessfully!',
                            textAlign:
                            TextAlign.center,
                            style:
                            TextStyle(
                              fontSize: 28,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          if (orderId
                              .isNotEmpty)
                            Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 22,
                                vertical: 9,
                              ),
                              decoration:
                              BoxDecoration(
                                color: AppColors
                                    .accentDark
                                    .withOpacity(
                                    0.07),
                                borderRadius:
                                BorderRadius
                                    .circular(
                                    30),
                              ),
                              child: Text(
                                'Order ID: #$orderId',
                                style:
                                const TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(
                            height: 28,
                          ),
                          Container(
                            width:
                            double.infinity,
                            padding:
                            const EdgeInsets
                                .all(20),
                            decoration:
                            BoxDecoration(
                              color:
                              Colors.white,
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors
                                      .black
                                      .withOpacity(
                                      0.06),
                                  blurRadius: 12,
                                  offset:
                                  const Offset(
                                    0,
                                    4,
                                  ),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                const Text(
                                  'Total Amount',
                                  style:
                                  TextStyle(
                                    fontSize:
                                    12,
                                    color:
                                    Colors.grey,
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  '₹${total.toStringAsFixed(2)}',
                                  style:
                                  const TextStyle(
                                    fontSize:
                                    26,
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 12,
                                ),
                                Text(
                                  'Payment: $paymentLabel',
                                  style:
                                  const TextStyle(
                                    fontSize:
                                    14,
                                    fontWeight:
                                    FontWeight
                                        .w600,
                                  ),
                                ),
                                if (transactionId
                                    .isNotEmpty) ...[
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Text(
                                    'Transaction ID: $transactionId',
                                    style:
                                    TextStyle(
                                      fontSize:
                                      12,
                                      color: Colors
                                          .grey[600],
                                    ),
                                  ),
                                ],
                                const SizedBox(
                                  height: 16,
                                ),
                                const Divider(),
                                const SizedBox(
                                  height: 12,
                                ),
                                Text(
                                  'Delivering to',
                                  style:
                                  const TextStyle(
                                    fontSize:
                                    15,
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                Text(
                                  address.fullName,
                                  style:
                                  const TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .w600,
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  address
                                      .singleLine,
                                  style:
                                  TextStyle(
                                    fontSize:
                                    13,
                                    color: Colors
                                        .grey[600],
                                  ),
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  address.phone,
                                  style:
                                  TextStyle(
                                    fontSize:
                                    13,
                                    color: Colors
                                        .grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding:
              EdgeInsets.fromLTRB(
                horizontalPad,
                12,
                horizontalPad,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                  BoxConstraints(
                    maxWidth:
                    maxContentWidth,
                  ),
                  child: SizedBox(
                    width:
                    double.infinity,
                    child:
                    ElevatedButton(
                      onPressed:
                      onContinue,
                      style:
                      ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        AppColors
                            .buttonPrimary,
                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 18,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                              14),
                        ),
                      ),
                      child:
                      const Text(
                        'CONTINUE SHOPPING',
                        style:
                        TextStyle(
                          color:
                          Colors.white,
                          fontSize:
                          16,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}