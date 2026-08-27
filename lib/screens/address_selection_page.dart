// import 'package:flutter/material.dart';
// import 'package:mtl_groceriesapp/screens/payment_method.dart';
// import 'package:provider/provider.dart';
//
// import '../config/app_color.dart';
// import '../model/address_model.dart';
// import '../model/cart_model.dart';
// import '../services/get_address_service.dart';
// import '../services/add_address_service.dart';
// import '../services/session_manager.dart';
// import '../widgets/refreshable_screen.dart';
// import 'add_address.dart';
//
//
// class AddressSelectionScreen extends StatefulWidget {
//   final String token;
//   final String customerId;
//
//   const AddressSelectionScreen({
//     super.key,
//     required this.token,
//     required this.customerId,
//   });
//
//   @override
//   State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
// }
//
// class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
//   List<AddressModel> _addresses = [];
//   bool _loading = true;
//
//   // Tracks which address card is currently being validated against the
//   // backend delivery zone, so we can show a spinner + disable taps.
//   String? _checkingAddressId;
//
//   // Tracks which address card is currently being deleted.
//   String? _deletingAddressId;
//
//   // Purely visual "picked" state.
//   String? _highlightedAddressId;
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   Future<void> _load() async {
//     setState(() => _loading = true);
//     try {
//       final token = await SessionManager.getString('token') ?? widget.token;
//       final list = await GetAddressApi.getAddresses(token: token);
//       if (mounted) {
//         setState(() {
//           _addresses = list;
//           _loading = false;
//           _highlightedAddressId = null;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _addresses = [];
//           _loading = false;
//         });
//       }
//     }
//   }
//
//   Future<void> _goToAddAddress() async {
//     final saved = await Navigator.push<bool>(
//       context,
//       MaterialPageRoute(
//         builder: (_) => AddAddressScreen(
//           token: widget.token,
//           customerId: widget.customerId,
//         ),
//       ),
//     );
//     if (saved == true) await _load();
//   }
//
//   void _highlightAddress(AddressModel address) {
//     setState(() {
//       _highlightedAddressId = (_highlightedAddressId == address.id) ? null : address.id;
//     });
//   }
//
//   // ✅ "Deliver here" — the only action that navigates to payment. Always
//   // re-checks the backend delivery zone live (never trusts a stale
//   // isDefault/latitude flag alone), throws an error dialog and stays on
//   // this screen if out of range, otherwise proceeds with the real,
//   // distance-based delivery fee returned by the backend.
//   Future<void> _selectAddress(AddressModel address) async {
//     if (address.latitude == null || address.longitude == null) {
//       _showDeliveryUnavailableDialog(
//         'This address has no saved location pin. Please edit it and set a location to continue.',
//       );
//       return;
//     }
//
//     setState(() => _checkingAddressId = address.id);
//
//     final token = await SessionManager.getString('token') ?? widget.token;
//
//     final result = await AddAddressApi.checkDeliveryZone(
//       token: token,
//       latitude: address.latitude!,
//       longitude: address.longitude!,
//     );
//
//     if (!mounted) return;
//     setState(() => _checkingAddressId = null);
//
//     if (!result.available) {
//       _showDeliveryUnavailableDialog(result.message); // ❌ stays on this screen
//       return;
//     }
//
//     // ✅ In range — proceed with the real, backend-confirmed delivery fee
//     final cart = Provider.of<CartModel>(context, listen: false);
//     final deliveryFee = result.deliveryCharge ?? 0;
//     final finalTotal  = cart.totalPrice + deliveryFee;
//
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => PaymentMethodScreen(
//           selectedAddress: address,
//           deliveryFee: deliveryFee,
//           finalTotal: finalTotal,
//         ),
//       ),
//     );
//   }
//
//   void _showDeliveryUnavailableDialog(String message) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Row(
//           children: [
//             Icon(Icons.location_off_rounded, color: AppColors.warning, size: 26),
//             SizedBox(width: 10),
//             Text('Delivery Unavailable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//           ],
//         ),
//         content: Text(
//           message.isNotEmpty ? message : 'We are unable to deliver to this address.',
//           style: const TextStyle(fontSize: 13, height: 1.5),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             style: TextButton.styleFrom(foregroundColor: AppColors.warning),
//             child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _confirmDelete(AddressModel address) async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Row(
//           children: [
//             Icon(Icons.delete_outline, color: Colors.red),
//             SizedBox(width: 8),
//             Text('Delete Address', style: TextStyle(fontWeight: FontWeight.bold)),
//           ],
//         ),
//         content: const Text('Are you sure you want to delete this address?'),
//         actions: [
//           OutlinedButton(
//             style: OutlinedButton.styleFrom(
//               side: const BorderSide(color: AppColors.buttonPrimary),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//             ),
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel', style: TextStyle(color: AppColors.buttonPrimary)),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//             ),
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//           ),
//         ],
//       ),
//     );
//
//     if (confirmed != true) return;
//
//     setState(() => _deletingAddressId = address.id);
//
//     final token = await SessionManager.getString('token') ?? widget.token;
//
//     final result = await AddAddressApi.deleteAddress(token: token, addressId: address.id);
//
//     if (!mounted) return;
//     setState(() => _deletingAddressId = null);
//
//     if (result.success) {
//       await _load();
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Address deleted'), backgroundColor: Colors.green),
//         );
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(result.message.isNotEmpty ? result.message : 'Failed to delete address. Please try again.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.white,
//       appBar: AppBar(
//         backgroundColor: AppColors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Padding(
//           padding: const EdgeInsets.only(right: 60),
//           child: Text('Choose Address',
//               style: TextStyle(color: AppColors.appBarText, fontWeight: FontWeight.bold, fontSize: 18)),
//         ),
//         centerTitle: true,
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel', style: TextStyle(color: AppColors.appBarText, fontWeight: FontWeight.w500)),
//           ),
//         ],
//       ),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox.shrink(),
//           Expanded(
//             child: _loading
//                 ? const Center(child: CircularProgressIndicator(color: AppColors.floatingCartBg))
//                 : RefreshableScreen(
//               onRefresh: _load,
//               color: AppColors.loader,
//               child: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
//                       child: Text('Select a saved address',
//                           style: TextStyle(fontSize: 13, color: AppColors.appBarText)),
//                     ),
//
//                     if (_addresses.isNotEmpty)
//                       ListView.builder(
//                         shrinkWrap: true,
//                         physics: const NeverScrollableScrollPhysics(),
//                         itemCount: _addresses.length,
//                         itemBuilder: (_, i) => _AddressCard(
//                           address: _addresses[i],
//                           isHighlighted: _highlightedAddressId == _addresses[i].id,
//                           isChecking: _checkingAddressId == _addresses[i].id,
//                           isDeleting: _deletingAddressId == _addresses[i].id,
//                           onTapCard: () => _highlightAddress(_addresses[i]),
//                           onSelect: () => _selectAddress(_addresses[i]),
//                           onDelete: () => _confirmDelete(_addresses[i]),
//                         ),
//                       ),
//
//                     if (_addresses.isEmpty)
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
//                         child: Text('No saved addresses. Add one below.',
//                             style: TextStyle(fontSize: 14, color: Colors.grey[500])),
//                       ),
//
//                     const SizedBox(height: 16),
//
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 20),
//                       child: SizedBox(
//                         width: double.infinity,
//                         child: OutlinedButton(
//                           onPressed: _goToAddAddress,
//                           style: OutlinedButton.styleFrom(
//                             side: const BorderSide(color: AppColors.buttonPrimary, width: 1.5),
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//                           ),
//                           child: const Text('+ Add new address',
//                               style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.buttonSecondaryText)),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//                     const Center(
//                       child: Text('or', style: TextStyle(fontSize: 14, color: AppColors.appBarText)),
//                     ),
//                     const SizedBox(height: 16),
//                     Center(
//                       child: TextButton(
//                         onPressed: () => Navigator.pop(context),
//                         child: const Text('Back to cart', style: TextStyle(fontSize: 16, color: AppColors.floatingCartBg)),
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─── Address Card ─────────────────────────────────────────────────────────────
// class _AddressCard extends StatelessWidget {
//   final AddressModel address;
//   final VoidCallback onTapCard;
//   final VoidCallback onSelect;
//   final VoidCallback onDelete;
//   final bool isHighlighted;
//   final bool isChecking;
//   final bool isDeleting;
//
//   const _AddressCard({
//     required this.address,
//     required this.onTapCard,
//     required this.onSelect,
//     required this.onDelete,
//     this.isHighlighted = false,
//     this.isChecking = false,
//     this.isDeleting = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final busy = isChecking || isDeleting;
//
//     return GestureDetector(
//       onTap: busy ? null : onTapCard,
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           border: Border.all(
//             color: isHighlighted ? AppColors.floatingCartBg : Colors.grey[300]!,
//             width: isHighlighted ? 2 : 1,
//           ),
//           borderRadius: BorderRadius.circular(12),
//           color: Colors.white,
//         ),
//         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Row(children: [
//             Container(
//               width: 18, height: 18,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 border: Border.all(color: isHighlighted ? AppColors.floatingCartBg : Colors.grey[400]!, width: 2),
//               ),
//               child: isHighlighted
//                   ? Center(
//                 child: Container(
//                   width: 9, height: 9,
//                   decoration: const BoxDecoration(color: AppColors.floatingCartBg, shape: BoxShape.circle),
//                 ),
//               )
//                   : null,
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: RichText(
//                 text: TextSpan(
//                   children: [
//                     TextSpan(
//                       text: address.fullName,
//                       style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
//                     ),
//                     if (address.isDefault)
//                       const TextSpan(
//                         text: '  (Default Address)',
//                         style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//             if (address.isDefault)
//               Container(
//                 margin: const EdgeInsets.only(right: 6),
//                 padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
//                 decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
//                 child: const Text('Default', style: TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold)),
//               ),
//             GestureDetector(
//               onTap: busy ? null : onDelete,
//               child: Padding(
//                 padding: const EdgeInsets.all(4),
//                 child: isDeleting
//                     ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
//                     : Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
//               ),
//             ),
//           ]),
//           const SizedBox(height: 8),
//           Padding(
//             padding: const EdgeInsets.only(left: 28),
//             child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//               Text(address.singleLine, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
//               const SizedBox(height: 2),
//               Text('Mobile: ${address.phone}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
//               const SizedBox(height: 10),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: busy ? null : onSelect,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.floatingCartBg,
//                     elevation: 0,
//                     padding: const EdgeInsets.symmetric(vertical: 10),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                   ),
//                   child: isChecking
//                       ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
//                       : const Text('Deliver here', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
//                 ),
//               ),
//             ]),
//           ),
//         ]),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/screens/payment_method.dart';
import 'package:provider/provider.dart';

import '../config/app_color.dart';
import '../model/address_model.dart';
import '../model/cart_model.dart';
import '../services/get_address_service.dart';
import '../services/add_address_service.dart';
import '../services/session_manager.dart';
import '../services/store_profile_cache.dart';
import '../widgets/refreshable_screen.dart';
import 'add_address.dart';


class AddressSelectionScreen extends StatefulWidget {
  final String token;
  final String customerId;

  const AddressSelectionScreen({
    super.key,
    required this.token,
    required this.customerId,
  });

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  List<AddressModel> _addresses = [];
  bool _loading = true;

  // Tracks which address card is currently being validated against the
  // backend delivery zone, so we can show a spinner + disable taps.
  String? _checkingAddressId;

  // Tracks which address card is currently being deleted.
  String? _deletingAddressId;

  // Purely visual "picked" state.
  String? _highlightedAddressId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await SessionManager.getString('token') ?? widget.token;
      final list = await GetAddressApi.getAddresses(token: token);
      if (mounted) {
        setState(() {
          _addresses = list;
          _loading = false;
          _highlightedAddressId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addresses = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _goToAddAddress() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(
          token: widget.token,
          customerId: widget.customerId,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  // ✅ NEW — opens Add Address screen pre-filled with the existing
  // address's data (edit mode), so the user can pin/re-pin its location.
  Future<void> _goToEditAddress(AddressModel address) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(
          token: widget.token,
          customerId: widget.customerId,
          existingAddress: address,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  void _highlightAddress(AddressModel address) {
    setState(() {
      _highlightedAddressId = (_highlightedAddressId == address.id) ? null : address.id;
    });
  }

  // ✅ "Deliver here" — the only action that navigates to payment. Always
  // re-checks the backend delivery zone live (never trusts a stale
  // isDefault/latitude flag alone), throws an error dialog and stays on
  // this screen if out of range, otherwise proceeds with the real,
  // distance-based delivery fee returned by the backend.
  Future<void> _selectAddress(AddressModel address) async {
    // ✅ No lat/lng saved — show a popup guiding the user to edit this
    // address and pin its location, instead of a plain error.
    if (address.latitude == null || address.longitude == null) {
      _showMissingLocationDialog(address);
      return;
    }

    setState(() => _checkingAddressId = address.id);

    final token = await SessionManager.getString('token') ?? widget.token;

    final result = await AddAddressApi.checkDeliveryZone(
      token: token,
      latitude: address.latitude!,
      longitude: address.longitude!,
    );

    if (!mounted) return;
    setState(() => _checkingAddressId = null);

    if (!result.available) {
      _showDeliveryUnavailableDialog(result.message);
      return;
    }

    // ✅ In range — start with the real, backend-confirmed distance-based
    // delivery fee, then override to FREE if the cart total meets the
    // store's free-delivery threshold (delivery_order_value — separate
    // from min_order_value, which is a cart-stage-only check).
    final cart = Provider.of<CartModel>(context, listen: false);
    double deliveryFee = result.deliveryCharge ?? 0;

    final freeDeliveryThreshold = StoreProfileCache.deliveryOrderValue;
    final qualifiesForFreeDelivery =
        freeDeliveryThreshold > 0 && cart.totalPrice >= freeDeliveryThreshold;

    if (qualifiesForFreeDelivery) {
      deliveryFee = 0;
    }

    final finalTotal = cart.totalPrice + deliveryFee;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(
          selectedAddress: address,
          deliveryFee: deliveryFee,
          finalTotal: finalTotal,
        ),
      ),
    );
  }

  // ✅ NEW — shown when an existing address has no lat/lng at all.
  // Offers a direct path into edit mode instead of just an error.
  void _showMissingLocationDialog(AddressModel address) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: AppColors.warning, size: 26),
            SizedBox(width: 10),
            Text('Location Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This address doesn\'t have a pinned location yet, so we can\'t calculate delivery for it.\n\n'
              'Please edit this address and set its exact location on the map.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog first
              _goToEditAddress(address);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Edit Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeliveryUnavailableDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: AppColors.warning, size: 26),
            SizedBox(width: 10),
            Text('Delivery Unavailable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message.isNotEmpty ? message : 'We are unable to deliver to this address.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(AddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Address', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.buttonPrimary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.buttonPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingAddressId = address.id);

    final token = await SessionManager.getString('token') ?? widget.token;

    final result = await AddAddressApi.deleteAddress(token: token, addressId: address.id);

    if (!mounted) return;
    setState(() => _deletingAddressId = null);

    if (result.success) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address deleted'), backgroundColor: Colors.green),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message.isNotEmpty ? result.message : 'Failed to delete address. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
          onPressed: () => Navigator.pop(context),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 60),
          child: Text('Choose Address',
              style: TextStyle(color: AppColors.appBarText, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.appBarText, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox.shrink(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.floatingCartBg))
                : RefreshableScreen(
              onRefresh: _load,
              color: AppColors.loader,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text('Select a saved address',
                          style: TextStyle(fontSize: 13, color: AppColors.appBarText)),
                    ),

                    if (_addresses.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _addresses.length,
                        itemBuilder: (_, i) => _AddressCard(
                          address: _addresses[i],
                          isHighlighted: _highlightedAddressId == _addresses[i].id,
                          isChecking: _checkingAddressId == _addresses[i].id,
                          isDeleting: _deletingAddressId == _addresses[i].id,
                          onTapCard: () => _highlightAddress(_addresses[i]),
                          onSelect: () => _selectAddress(_addresses[i]),
                          onDelete: () => _confirmDelete(_addresses[i]),
                          onEdit: () => _goToEditAddress(_addresses[i]), // ✅ NEW
                        ),
                      ),

                    if (_addresses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text('No saved addresses. Add one below.',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                      ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _goToAddAddress,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.buttonPrimary, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('+ Add new address',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.buttonSecondaryText)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text('or', style: TextStyle(fontSize: 14, color: AppColors.appBarText)),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back to cart', style: TextStyle(fontSize: 16, color: AppColors.floatingCartBg)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Address Card ─────────────────────────────────────────────────────────────
class _AddressCard extends StatelessWidget {
  final AddressModel address;
  final VoidCallback onTapCard;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onEdit; // ✅ NEW
  final bool isHighlighted;
  final bool isChecking;
  final bool isDeleting;

  const _AddressCard({
    required this.address,
    required this.onTapCard,
    required this.onSelect,
    required this.onDelete,
    required this.onEdit,
    this.isHighlighted = false,
    this.isChecking = false,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final busy = isChecking || isDeleting;
    final hasLocation = address.latitude != null && address.longitude != null;

    return GestureDetector(
      onTap: busy ? null : onTapCard,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isHighlighted ? AppColors.floatingCartBg : Colors.grey[300]!,
            width: isHighlighted ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isHighlighted ? AppColors.floatingCartBg : Colors.grey[400]!, width: 2),
              ),
              child: isHighlighted
                  ? Center(
                child: Container(
                  width: 9, height: 9,
                  decoration: const BoxDecoration(color: AppColors.floatingCartBg, shape: BoxShape.circle),
                ),
              )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: address.fullName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    if (address.isDefault)
                      const TextSpan(
                        text: '  (Default Address)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                  ],
                ),
              ),
            ),
            if (address.isDefault)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8)),
                child: const Text('Default', style: TextStyle(fontSize: 10, color: AppColors.textDark, fontWeight: FontWeight.bold)),
              ),
            // ✅ NEW — edit icon
            GestureDetector(
              onTap: busy ? null : onEdit,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined, size: 19, color: Colors.grey.shade600),
              ),
            ),
            GestureDetector(
              onTap: busy ? null : onDelete,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: isDeleting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                    : Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(address.singleLine, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
              const SizedBox(height: 2),
              Text('Mobile: ${address.phone}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),

              // ✅ NEW — subtle hint when this address has no pinned
              // location, so the user isn't surprised by the popup.
              if (!hasLocation) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.location_off_rounded, size: 13, color: AppColors.warning),
                  const SizedBox(width: 4),
                  const Text('Location not pinned',
                      style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500)),
                ]),
              ],

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : onSelect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.floatingCartBg,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isChecking
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Deliver here', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}