// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:provider/provider.dart';
// import 'package:mtl_groceriesapp/model/cart_model.dart';
//
// import '../products/product_detail_screen.dart';
// import '../services/api_config_service.dart';
// import '../services/get_profile_service.dart';
// import '../services/session_manager.dart';
// import 'address_selection_page.dart';
//
// final String _kImgBase = ApiConfig.imageBase;
//
// Widget _safeProductImage(String image, String imageUrl) {
//   String url = '';
//   if (imageUrl.isNotEmpty && imageUrl != 'no_image.png') {
//     url = imageUrl.startsWith('http') ? imageUrl : '$_kImgBase$imageUrl';
//   } else if (image.isNotEmpty && image != 'no_image.png') {
//     url = image.startsWith('http') ? image : '$_kImgBase$image';
//   }
//
//   if (url.isNotEmpty) {
//     return Image.network(
//       url,
//       fit: BoxFit.cover,
//       loadingBuilder: (_, child, prog) =>
//       prog == null ? child : Container(color: const Color(0xFFF5F5F5)),
//       errorBuilder: (_, __, ___) => _imgPlaceholder(),
//     );
//   }
//   return _imgPlaceholder();
// }
//
// Widget _imgPlaceholder() => Container(
//   color: const Color(0xFFF5F5F5),
//   child: const Center(
//     child: Icon(Icons.image_not_supported, color: Colors.grey, size: 30),
//   ),
// );
//
// class CartScreen extends StatefulWidget {
//   final VoidCallback? onGoToHome;
//   final VoidCallback? onRefresh;
//
//   final String token;
//   final String customerId;
//
//   const CartScreen({
//     super.key,
//     this.onGoToHome,
//     this.onRefresh,
//     required this.token,
//     required this.customerId,
//   });
//
//   @override
//   State<CartScreen> createState() => _CartScreenState();
// }
//
// class _CartScreenState extends State<CartScreen> {
//   double _minOrderValue = 0;
//   double _deliveryFee = 0;
//   double _finalTotal = 0;
//   bool _feeLoading = false;
//   double _lastFetchedAmount = -1;
//
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchMinOrderValue();
//   }
//   Future<void> _fetchDeliveryFee(double amount) async {
//     if (!mounted) return;
//     setState(() => _feeLoading = true);
//     try {
//       final token = await SessionManager.getString('token') ?? widget.token;
//       final uri = Uri.parse(
//         '${ApiConfig.baseUrl}index.php?route=groceries/categories.getDeliveryFee&token=$token',
//       );
//       final res = await http.post(uri, body: {'amount': amount.toStringAsFixed(0)});
//       if (!mounted) return;
//       final data = jsonDecode(res.body) as Map<String, dynamic>;
//       if (data['status'] == 'success') {
//         setState(() {
//           _deliveryFee = (data['delivery_fee'] as num).toDouble();
//           _finalTotal  = (data['final_total']  as num).toDouble();
//           _feeLoading  = false;
//         });
//       }
//     } catch (_) {
//       if (mounted) setState(() => _feeLoading = false);
//     }
//   }
//
//   Future<void> _fetchMinOrderValue() async {
//     try {
//       final result = await ProfileGetApiService.getProfile();
//       if (result['success'] == true) {
//         final data = result['data'] as Map<String, dynamic>;
//         final minStr = data['min_order_value'] as String? ?? '0';
//         if (mounted) {
//           setState(() {
//             _minOrderValue = double.tryParse(minStr) ?? 0;
//           });
//         }
//       }
//     } catch (_) {}
//   }
//
//   void _goToHome(BuildContext context) {
//     if (widget.onGoToHome != null) {
//       widget.onGoToHome!();
//     } else {
//       Navigator.of(context).popUntil((route) => route.isFirst);
//     }
//   }
//
//   Future<void> _handleProceed(BuildContext context, double totalPrice) async {
//     if (_minOrderValue > 0 && totalPrice < _minOrderValue) {
//       await showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           shape:
//           RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           title: const Row(
//             children: [
//               Icon(Icons.info_outline, color: Color(0xFFFF0080)),
//               SizedBox(width: 8),
//               Text('Minimum Order',
//                   style: TextStyle(fontWeight: FontWeight.bold)),
//             ],
//           ),
//           content: Text(
//             'Your order total is ₹${totalPrice.toStringAsFixed(0)}, but the minimum order value is ₹${_minOrderValue.toStringAsFixed(0)}.\n\nPlease add more items to proceed.',
//           ),
//           actions: [
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFFFF0080),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8)),
//               ),
//               onPressed: () => Navigator.pop(context),
//               child:
//               const Text('OK', style: TextStyle(color: Colors.white)),
//             ),
//           ],
//         ),
//       );
//       return;
//     }
//
//     final token = await SessionManager.getString('token') ?? widget.token;
//     final customerId = await SessionManager.getString('customer_id') ?? widget.customerId;
//
//     if (token.isEmpty) return;
//
//     await _fetchDeliveryFee(totalPrice); // ✅ ADD THIS LINE
//
//     if (!mounted) return;
//
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => AddressSelectionScreen(
//           token: token,
//           customerId: customerId,
//           deliveryFee: _deliveryFee,
//           finalTotal: _finalTotal,
//         ),
//       ),
//     );
//     if (widget.onRefresh != null) widget.onRefresh!();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final screenW = MediaQuery.of(context).size.width;
//     final screenH = MediaQuery.of(context).size.height;
//
//     return Scaffold(
//       backgroundColor: const Color(0xFFFFFFFF),
//       appBar: AppBar(
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
//               begin: Alignment.centerLeft,
//               end: Alignment.centerRight,
//             ),
//           ),
//         ),
//         elevation: 0,
//         title: const Text(
//           'My Cart',
//           style:
//           TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 16),
//             child: Consumer<CartModel>(
//               builder: (context, cart, _) {
//                 final totalItems = cart.items.values
//                     .fold(0, (sum, item) => sum + item.quantity);
//                 return Center(
//                   child: Text(
//                     '$totalItems ${totalItems == 1 ? 'item' : 'items'}',
//                     style:
//                     const TextStyle(color: Colors.black38, fontSize: 13),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//       body: Consumer<CartModel>(
//         builder: (context, cart, child) {
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             if (!_feeLoading && _lastFetchedAmount != cart.totalPrice) {
//               _lastFetchedAmount = cart.totalPrice;
//               _fetchDeliveryFee(cart.totalPrice);
//             }
//           });
//           // ── Empty state ────────────────────────────────────────────────
//           if (cart.items.isEmpty) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Container(
//                     width: screenW * 0.35,
//                     height: screenW * 0.35,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       border: Border.all(
//                           color: const Color(0xFFD4A96A),
//                           width: 1.5,
//                           style: BorderStyle.solid),
//                     ),
//                     child: Center(
//                       child: Icon(Icons.shopping_cart_outlined,
//                           size: screenW * 0.18,
//                           color: const Color(0xFFD4A96A)),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Text('Nothing here yet!',
//                       style: TextStyle(
//                           fontSize: screenW * 0.05,
//                           color: const Color(0xFFFF0080),
//                           fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 8),
//                   Text('Your cart is waiting to be filled',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                           fontSize: screenW * 0.035,
//                           color: Colors.grey[500])),
//                   SizedBox(height: screenH * 0.03),
//                   ElevatedButton(
//                     onPressed: () => _goToHome(context),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFFFF0080),
//                       padding: EdgeInsets.symmetric(
//                           horizontal: screenW * 0.1,
//                           vertical: screenH * 0.015),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(24)),
//                     ),
//                     child: Text('Start Shopping',
//                         style: TextStyle(
//                             color: Colors.white,
//                             fontSize: screenW * 0.04,
//                             fontWeight: FontWeight.bold)),
//                   ),
//                 ],
//               ),
//             );
//           }
//
//           // ── Cart list ──────────────────────────────────────────────────
//           return Column(
//             children: [
//               // ── Free delivery banner (backend-driven) ──────────────────
//               // if (_minOrderValue > 0 && cart.totalPrice >= _minOrderValue)
//               if (_minOrderValue > 0 && cart.totalPrice >= _minOrderValue && _deliveryFee == 0 && _finalTotal > 0)
//                 Container(
//                   width: double.infinity,
//                   color: const Color(0xFF0C831F),
//                   padding: EdgeInsets.symmetric(
//                       vertical: screenH * 0.01,
//                       horizontal: screenW * 0.04),
//                   child: const Row(
//                     children: [
//                       Icon(Icons.local_shipping,
//                           color: Colors.white, size: 16),
//                       SizedBox(width: 8),
//                       Text('Free delivery on this order! 🎉',
//                           style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 13,
//                               fontWeight: FontWeight.w500)),
//                     ],
//                   ),
//                 ),
//
//               // ── Minimum order progress bar ─────────────────────────────
//               if (_minOrderValue > 0 && cart.totalPrice < _minOrderValue)
//                 Container(
//                   width: double.infinity,
//                   color: const Color(0xFFFFF3E0),
//                   padding: EdgeInsets.symmetric(
//                       vertical: screenH * 0.012,
//                       horizontal: screenW * 0.04),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           const Icon(Icons.shopping_bag_outlined,
//                               color: Color(0xFFFF0080), size: 15),
//                           const SizedBox(width: 6),
//                           Expanded(
//                             child: Text(
//                               'Add ₹${(_minOrderValue - cart.totalPrice).toStringAsFixed(0)} more to meet minimum order value',
//                               style: const TextStyle(
//                                   fontSize: 12,
//                                   color: Color(0xFFFF0080),
//                                   fontWeight: FontWeight.w500),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 6),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(4),
//                         child: LinearProgressIndicator(
//                           value: (cart.totalPrice / _minOrderValue)
//                               .clamp(0.0, 1.0),
//                           minHeight: 5,
//                           backgroundColor: const Color(0xFFE0C8A0),
//                           valueColor: const AlwaysStoppedAnimation<Color>(
//                               Color(0xFFFF0080)),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//               Expanded(
//                 child: RefreshIndicator(
//                   color: const Color(0xFFFF0080),
//                   onRefresh: _fetchMinOrderValue,
//                   child: ListView(
//                     padding: EdgeInsets.all(screenW * 0.03),
//                     children: [
//                       // ── Cart items card ────────────────────────────────
//                       Container(
//                         decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(12)),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Padding(
//                               padding: EdgeInsets.fromLTRB(
//                                   screenW * 0.04,
//                                   screenH * 0.018,
//                                   screenW * 0.04,
//                                   screenH * 0.005),
//                               child: Text('Items in your cart',
//                                   style: TextStyle(
//                                       fontSize: screenW * 0.04,
//                                       fontWeight: FontWeight.bold)),
//                             ),
//                             ...cart.items.values.toList().map((item) {
//                               return Column(
//                                 children: [
//                                   Divider(
//                                       height: 1,
//                                       color: Colors.grey.shade100),
//                                   InkWell(
//                                     onTap: () {
//                                       Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                           builder: (_) =>
//                                               ProductDetailScreen(
//                                                 product: item.product,
//                                               ),
//                                         ),
//                                       );
//                                     },
//                                     borderRadius: BorderRadius.circular(8),
//                                     child: Padding(
//                                       padding:
//                                       EdgeInsets.all(screenW * 0.03),
//                                       child: Row(
//                                         children: [
//                                           Container(
//                                             width: screenW * 0.16,
//                                             height: screenW * 0.16,
//                                             decoration: BoxDecoration(
//                                               color:
//                                               const Color(0xFFF5F5F5),
//                                               borderRadius:
//                                               BorderRadius.circular(8),
//                                             ),
//                                             child: ClipRRect(
//                                               borderRadius:
//                                               BorderRadius.circular(8),
//                                               child: _safeProductImage(
//                                                 item.product.image,
//                                                 item.product.imageUrl,
//                                               ),
//                                             ),
//                                           ),
//                                           SizedBox(width: screenW * 0.03),
//                                           Expanded(
//                                             child: Column(
//                                               crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                               children: [
//                                                 Text(item.product.name,
//                                                     maxLines: 2,
//                                                     overflow: TextOverflow
//                                                         .ellipsis,
//                                                     style: TextStyle(
//                                                         fontSize:
//                                                         screenW * 0.036,
//                                                         fontWeight:
//                                                         FontWeight
//                                                             .w600)),
//                                                 if (item.product.weight
//                                                     .isNotEmpty) ...[
//                                                   SizedBox(
//                                                       height:
//                                                       screenH * 0.003),
//                                                   Text(item.product.weight,
//                                                       style: TextStyle(
//                                                           fontSize:
//                                                           screenW * 0.03,
//                                                           color: Colors
//                                                               .grey[600])),
//                                                 ],
//                                                 SizedBox(
//                                                     height: screenH * 0.006),
//                                                 Row(
//                                                   children: [
//                                                     Text(
//                                                       '₹${item.product.price.toStringAsFixed(0)}',
//                                                       style: TextStyle(
//                                                           fontSize:
//                                                           screenW * 0.038,
//                                                           fontWeight:
//                                                           FontWeight.bold,
//                                                           color: const Color(
//                                                               0xFF0C831F)),
//                                                     ),
//                                                     if (item.product
//                                                         .originalPrice >
//                                                         item.product
//                                                             .price) ...[
//                                                       SizedBox(
//                                                           width:
//                                                           screenW * 0.015),
//                                                       Text(
//                                                         '₹${item.product.originalPrice.toStringAsFixed(0)}',
//                                                         style: TextStyle(
//                                                             fontSize:
//                                                             screenW * 0.03,
//                                                             color:
//                                                             Colors.grey,
//                                                             decoration:
//                                                             TextDecoration
//                                                                 .lineThrough),
//                                                       ),
//                                                     ],
//                                                   ],
//                                                 ),
//                                                 SizedBox(
//                                                     height: screenH * 0.004),
//                                                 Row(
//                                                   children: [
//                                                     Icon(Icons.info_outline,
//                                                         size: 11,
//                                                         color:
//                                                         Colors.grey[400]),
//                                                     const SizedBox(width: 3),
//                                                     Text('Tap to view details',
//                                                         style: TextStyle(
//                                                             fontSize:
//                                                             screenW * 0.028,
//                                                             color: Colors
//                                                                 .grey[400])),
//                                                   ],
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                           GestureDetector(
//                                             behavior:
//                                             HitTestBehavior.opaque,
//                                             onTap: () {},
//                                             child: Container(
//                                               decoration: BoxDecoration(
//                                                   color: const Color(
//                                                       0xFFFF0080),
//                                                   borderRadius:
//                                                   BorderRadius.circular(
//                                                       8)),
//                                               child: Row(
//                                                 mainAxisSize:
//                                                 MainAxisSize.min,
//                                                 children: [
//                                                   InkWell(
//                                                     onTap: () => cart
//                                                         .decrementQuantity(
//                                                         item.product.id),
//                                                     child: Padding(
//                                                       padding: EdgeInsets
//                                                           .symmetric(
//                                                           horizontal:
//                                                           screenW *
//                                                               0.02,
//                                                           vertical:
//                                                           screenH *
//                                                               0.008),
//                                                       child: const Icon(
//                                                           Icons.remove,
//                                                           color: Colors.white,
//                                                           size: 18),
//                                                     ),
//                                                   ),
//                                                   Text('${item.quantity}',
//                                                       style: TextStyle(
//                                                           color: Colors.white,
//                                                           fontWeight:
//                                                           FontWeight.bold,
//                                                           fontSize:
//                                                           screenW * 0.04)),
//                                                   InkWell(
//                                                     onTap: () => cart
//                                                         .incrementQuantity(
//                                                         item.product.id),
//                                                     child: Padding(
//                                                       padding: EdgeInsets
//                                                           .symmetric(
//                                                           horizontal:
//                                                           screenW *
//                                                               0.02,
//                                                           vertical:
//                                                           screenH *
//                                                               0.008),
//                                                       child: const Icon(
//                                                           Icons.add,
//                                                           color: Colors.white,
//                                                           size: 18),
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ],
//                         ),
//                       ),
//
//                       SizedBox(height: screenH * 0.015),
//
//                       // ── Bill details ───────────────────────────────────
//                       Container(
//                         decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(12)),
//                         padding: EdgeInsets.all(screenW * 0.04),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('Bill Details',
//                                 style: TextStyle(
//                                     fontSize: screenW * 0.04,
//                                     fontWeight: FontWeight.bold)),
//                             SizedBox(height: screenH * 0.015),
//                             _BillRow(
//                                 label: 'Items total',
//                                 value: '₹${cart.totalPrice.toStringAsFixed(0)}'),
//                             _BillRow(
//                                 label: 'Delivery fee',
//                                 value: _feeLoading ? '...' : '₹${_deliveryFee.toStringAsFixed(0)}',
//                                 valueColor: _deliveryFee == 0 ? const Color(0xFF0C831F) : null),
//                             const _BillRow(
//                                 label: 'Handling fee',
//                                 value: '₹0',
//                                 valueColor: Color(0xFF0C831F)),
//                             Divider(
//                                 color: Colors.grey.shade200, height: 20),
//                             _BillRow(
//                                 label: 'Grand Total',
//                                 value: _feeLoading
//                                     ? '₹${cart.totalPrice.toStringAsFixed(0)}'
//                                     : '₹${_finalTotal.toStringAsFixed(0)}',
//                                 isBold: true),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//
//               // ── Checkout bar ───────────────────────────────────────────
//               Container(
//                 padding: EdgeInsets.fromLTRB(
//                     screenW * 0.04,
//                     screenH * 0.015,
//                     screenW * 0.04,
//                     MediaQuery.of(context).padding.bottom + screenH * 0.015),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   boxShadow: [
//                     BoxShadow(
//                         color: Colors.black.withValues(alpha: 0.1),
//                         blurRadius: 10,
//                         offset: const Offset(0, -2))
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(
//                             _feeLoading
//                                 ? '₹${cart.totalPrice.toStringAsFixed(0)}'
//                                 : '₹${_finalTotal.toStringAsFixed(0)}',
//                             style: TextStyle(
//                                 fontSize: screenW * 0.05,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.black)),
//                         Text('Total bill',
//                             style: TextStyle(
//                                 fontSize: screenW * 0.03,
//                                 color: Colors.grey)),
//                       ],
//                     ),
//                     const Spacer(),
//                     ElevatedButton(
//                       onPressed: () =>
//                           _handleProceed(context, cart.totalPrice),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFFFF0080),
//                         padding: EdgeInsets.symmetric(
//                             horizontal: screenW * 0.08,
//                             vertical: screenH * 0.018),
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12)),
//                       ),
//                       child: Text('PROCEED',
//                           style: TextStyle(
//                               color: Colors.white,
//                               fontSize: screenW * 0.042,
//                               fontWeight: FontWeight.bold)),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }
//
// class _BillRow extends StatelessWidget {
//   final String label;
//   final String value;
//   final Color? valueColor;
//   final bool isBold;
//
//   const _BillRow({
//     required this.label,
//     required this.value,
//     this.valueColor,
//     this.isBold = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final screenW = MediaQuery.of(context).size.width;
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label,
//               style: TextStyle(
//                   fontSize: screenW * 0.035,
//                   color: isBold ? Colors.black : Colors.grey[700],
//                   fontWeight:
//                   isBold ? FontWeight.bold : FontWeight.normal)),
//           Text(value,
//               style: TextStyle(
//                   fontSize: screenW * 0.035,
//                   fontWeight:
//                   isBold ? FontWeight.bold : FontWeight.w500,
//                   color: valueColor ??
//                       (isBold ? Colors.black : Colors.black87))),
//         ],
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:mtl_groceriesapp/model/cart_model.dart';

import '../products/product_detail_screen.dart';
import '../services/api_config_service.dart';
import '../services/get_profile_service.dart';
import '../services/session_manager.dart';
import 'address_selection_page.dart';

final String _kImgBase = ApiConfig.imageBase;

Widget _safeProductImage(String image, String imageUrl) {
  String url = '';
  if (imageUrl.isNotEmpty && imageUrl != 'no_image.png') {
    url = imageUrl.startsWith('http') ? imageUrl : '$_kImgBase$imageUrl';
  } else if (image.isNotEmpty && image != 'no_image.png') {
    url = image.startsWith('http') ? image : '$_kImgBase$image';
  }

  if (url.isNotEmpty) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, prog) =>
      prog == null ? child : Container(color: const Color(0xFFF5F5F5)),
      errorBuilder: (_, __, ___) => _imgPlaceholder(),
    );
  }
  return _imgPlaceholder();
}

Widget _imgPlaceholder() => Container(
  color: const Color(0xFFF5F5F5),
  child: const Center(
    child: Icon(Icons.image_not_supported, color: Colors.grey, size: 30),
  ),
);

class CartScreen extends StatefulWidget {
  final VoidCallback? onGoToHome;
  final VoidCallback? onRefresh;

  final String token;
  final String customerId;

  const CartScreen({
    super.key,
    this.onGoToHome,
    this.onRefresh,
    required this.token,
    required this.customerId,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double _minOrderValue = 0;
  double _deliveryFee = 0;
  double _finalTotal = 0;
  // bool _feeLoading = false;
  double _lastFetchedAmount = -1;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchMinOrderValue();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchDeliveryFee(double amount) async {
    if (!mounted) return;

    try {
      final token = await SessionManager.getString('token') ?? widget.token;
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}index.php?route=groceries/categories.getDeliveryFee&token=$token',
      );
      final res = await http.post(uri, body: {'amount': amount.toStringAsFixed(0)});
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'success') {
        setState(() {
          _deliveryFee = (data['delivery_fee'] as num).toDouble();
          _finalTotal  = (data['final_total']  as num).toDouble();

        });
      }
    } catch (_) {

    }
  }

  Future<void> _fetchMinOrderValue() async {
    try {
      final result = await ProfileGetApiService.getProfile();
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final minStr = data['min_order_value'] as String? ?? '0';
        if (mounted) {
          setState(() {
            _minOrderValue = double.tryParse(minStr) ?? 0;
          });
        }
      }
    } catch (_) {}
  }

  void _goToHome(BuildContext context) {
    if (widget.onGoToHome != null) {
      widget.onGoToHome!();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _handleProceed(BuildContext context, double totalPrice) async {
    if (_minOrderValue > 0 && totalPrice < _minOrderValue) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFFF0080)),
              SizedBox(width: 8),
              Text('Minimum Order',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Your order total is ₹${totalPrice.toStringAsFixed(0)}, but the minimum order value is ₹${_minOrderValue.toStringAsFixed(0)}.\n\nPlease add more items to proceed.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0080),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              child:
              const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final token = await SessionManager.getString('token') ?? widget.token;
    final customerId = await SessionManager.getString('customer_id') ?? widget.customerId;

    if (token.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF0080)),
      ),
    );

    await _fetchDeliveryFee(totalPrice);

    if (!mounted) return;

    Navigator.pop(context);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressSelectionScreen(
          token: token,
          customerId: customerId,
          deliveryFee: _deliveryFee,
          finalTotal: _finalTotal,
        ),
      ),
    );
    if (widget.onRefresh != null) widget.onRefresh!();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        elevation: 0,
        title: const Text(
          'My Cart',
          style:
          TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Consumer<CartModel>(
              builder: (context, cart, _) {
                final totalItems = cart.items.values
                    .fold(0, (sum, item) => sum + item.quantity);
                return Center(
                  child: Text(
                    '$totalItems ${totalItems == 1 ? 'item' : 'items'}',
                    style:
                    const TextStyle(color: Colors.black38, fontSize: 13),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Consumer<CartModel>(
        builder: (context, cart, child) {
          // ── Debounced delivery fee fetch ───────────────────────────────
          if (_lastFetchedAmount != cart.totalPrice) {
            _lastFetchedAmount = cart.totalPrice;
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 600), () {
              _fetchDeliveryFee(cart.totalPrice);
            });
          }

          // ── Empty state ────────────────────────────────────────────────
          if (cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: screenW * 0.35,
                    height: screenW * 0.35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFD4A96A),
                          width: 1.5,
                          style: BorderStyle.solid),
                    ),
                    child: Center(
                      child: Icon(Icons.shopping_cart_outlined,
                          size: screenW * 0.18,
                          color: const Color(0xFFD4A96A)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Nothing here yet!',
                      style: TextStyle(
                          fontSize: screenW * 0.05,
                          color: const Color(0xFFFF0080),
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Your cart is waiting to be filled',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: screenW * 0.035,
                          color: Colors.grey[500])),
                  SizedBox(height: screenH * 0.03),
                  ElevatedButton(
                    onPressed: () => _goToHome(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0080),
                      padding: EdgeInsets.symmetric(
                          horizontal: screenW * 0.1,
                          vertical: screenH * 0.015),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('Start Shopping',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: screenW * 0.04,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          // ── Cart list ──────────────────────────────────────────────────
          return Column(
            children: [
              // ── Free delivery banner (backend-driven) ──────────────────
              if (_minOrderValue > 0 && cart.totalPrice >= _minOrderValue && _deliveryFee == 0 && _finalTotal > 0)
                Container(
                  width: double.infinity,
                  color: const Color(0xFF0C831F),
                  padding: EdgeInsets.symmetric(
                      vertical: screenH * 0.01,
                      horizontal: screenW * 0.04),
                  child: const Row(
                    children: [
                      Icon(Icons.local_shipping,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Free delivery on this order! 🎉',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

              // ── Minimum order progress bar ─────────────────────────────
              if (_minOrderValue > 0 && cart.totalPrice < _minOrderValue)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF3E0),
                  padding: EdgeInsets.symmetric(
                      vertical: screenH * 0.012,
                      horizontal: screenW * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined,
                              color: Color(0xFFFF0080), size: 15),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Add ₹${(_minOrderValue - cart.totalPrice).toStringAsFixed(0)} more to meet minimum order value',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFFF0080),
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (cart.totalPrice / _minOrderValue)
                              .clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: const Color(0xFFE0C8A0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF0080)),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFFFF0080),
                  onRefresh: _fetchMinOrderValue,
                  child: ListView(
                    padding: EdgeInsets.all(screenW * 0.03),
                    children: [
                      // ── Cart items card ────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                  screenW * 0.04,
                                  screenH * 0.018,
                                  screenW * 0.04,
                                  screenH * 0.005),
                              child: Text('Items in your cart',
                                  style: TextStyle(
                                      fontSize: screenW * 0.04,
                                      fontWeight: FontWeight.bold)),
                            ),
                            ...cart.items.values.toList().map((item) {
                              return Column(
                                children: [
                                  Divider(
                                      height: 1,
                                      color: Colors.grey.shade100),
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ProductDetailScreen(
                                                product: item.product,
                                              ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding:
                                      EdgeInsets.all(screenW * 0.03),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: screenW * 0.16,
                                            height: screenW * 0.16,
                                            decoration: BoxDecoration(
                                              color:
                                              const Color(0xFFF5F5F5),
                                              borderRadius:
                                              BorderRadius.circular(8),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                              BorderRadius.circular(8),
                                              child: _safeProductImage(
                                                item.product.image,
                                                item.product.imageUrl,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: screenW * 0.03),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Text(item.product.name,
                                                    maxLines: 2,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style: TextStyle(
                                                        fontSize:
                                                        screenW * 0.036,
                                                        fontWeight:
                                                        FontWeight
                                                            .w600)),
                                                if (item.product.weight
                                                    .isNotEmpty) ...[
                                                  SizedBox(
                                                      height:
                                                      screenH * 0.003),
                                                  Text(item.product.weight,
                                                      style: TextStyle(
                                                          fontSize:
                                                          screenW * 0.03,
                                                          color: Colors
                                                              .grey[600])),
                                                ],
                                                SizedBox(
                                                    height: screenH * 0.006),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '₹${item.product.price.toStringAsFixed(0)}',
                                                      style: TextStyle(
                                                          fontSize:
                                                          screenW * 0.038,
                                                          fontWeight:
                                                          FontWeight.bold,
                                                          color: const Color(
                                                              0xFF0C831F)),
                                                    ),
                                                    if (item.product
                                                        .originalPrice >
                                                        item.product
                                                            .price) ...[
                                                      SizedBox(
                                                          width:
                                                          screenW * 0.015),
                                                      Text(
                                                        '₹${item.product.originalPrice.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                            fontSize:
                                                            screenW * 0.03,
                                                            color:
                                                            Colors.grey,
                                                            decoration:
                                                            TextDecoration
                                                                .lineThrough),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                SizedBox(
                                                    height: screenH * 0.004),
                                                Row(
                                                  children: [
                                                    Icon(Icons.info_outline,
                                                        size: 11,
                                                        color:
                                                        Colors.grey[400]),
                                                    const SizedBox(width: 3),
                                                    Text('Tap to view details',
                                                        style: TextStyle(
                                                            fontSize:
                                                            screenW * 0.028,
                                                            color: Colors
                                                                .grey[400])),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          GestureDetector(
                                            behavior:
                                            HitTestBehavior.opaque,
                                            onTap: () {},
                                            child: Container(
                                              decoration: BoxDecoration(
                                                  color: const Color(
                                                      0xFFFF0080),
                                                  borderRadius:
                                                  BorderRadius.circular(
                                                      8)),
                                              child: Row(
                                                mainAxisSize:
                                                MainAxisSize.min,
                                                children: [
                                                  InkWell(
                                                    onTap: () => cart
                                                        .decrementQuantity(
                                                        item.product.id),
                                                    child: Padding(
                                                      padding: EdgeInsets
                                                          .symmetric(
                                                          horizontal:
                                                          screenW *
                                                              0.02,
                                                          vertical:
                                                          screenH *
                                                              0.008),
                                                      child: const Icon(
                                                          Icons.remove,
                                                          color: Colors.white,
                                                          size: 18),
                                                    ),
                                                  ),
                                                  Text('${item.quantity}',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                          FontWeight.bold,
                                                          fontSize:
                                                          screenW * 0.04)),
                                                  InkWell(
                                                    onTap: () => cart
                                                        .incrementQuantity(
                                                        item.product.id),
                                                    child: Padding(
                                                      padding: EdgeInsets
                                                          .symmetric(
                                                          horizontal:
                                                          screenW *
                                                              0.02,
                                                          vertical:
                                                          screenH *
                                                              0.008),
                                                      child: const Icon(
                                                          Icons.add,
                                                          color: Colors.white,
                                                          size: 18),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                      SizedBox(height: screenH * 0.015),

                      // ── Bill details ───────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.all(screenW * 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bill Details',
                                style: TextStyle(
                                    fontSize: screenW * 0.04,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: screenH * 0.015),
                            _BillRow(
                                label: 'Items total',
                                value: '₹${cart.totalPrice.toStringAsFixed(0)}'),
                            _BillRow(
                                label: 'Delivery fee',
                                value: '₹${_deliveryFee.toStringAsFixed(0)}',
                                valueColor: _deliveryFee == 0 ? const Color(0xFF0C831F) : null),
                            const _BillRow(
                                label: 'Handling fee',
                                value: '₹0',
                                valueColor: Color(0xFF0C831F)),
                            Divider(
                                color: Colors.grey.shade200, height: 20),
                            _BillRow(
                                label: 'Grand Total',
                                value: '₹${_finalTotal.toStringAsFixed(0)}',
                                isBold: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Checkout bar ───────────────────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(
                    screenW * 0.04,
                    screenH * 0.015,
                    screenW * 0.04,
                    MediaQuery.of(context).padding.bottom + screenH * 0.015),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2))
                  ],
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            '₹${_finalTotal.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: screenW * 0.05,
                                fontWeight: FontWeight.bold,
                                color: Colors.black)),
                        Text('Total bill',
                            style: TextStyle(
                                fontSize: screenW * 0.03,
                                color: Colors.grey)),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () =>
                          _handleProceed(context, cart.totalPrice),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0080),
                        padding: EdgeInsets.symmetric(
                            horizontal: screenW * 0.08,
                            vertical: screenH * 0.018),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('PROCEED',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: screenW * 0.042,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _BillRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: screenW * 0.035,
                  color: isBold ? Colors.black : Colors.grey[700],
                  fontWeight:
                  isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: screenW * 0.035,
                  fontWeight:
                  isBold ? FontWeight.bold : FontWeight.w500,
                  color: valueColor ??
                      (isBold ? Colors.black : Colors.black87))),
        ],
      ),
    );
  }
}