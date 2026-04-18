import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/screens/payment_method.dart';

import '../model/address_model.dart';
import '../services/get_address_service.dart';
import '../services/session_manager.dart';
import '../widgets/refreshable_screen.dart';
import 'add_address.dart';


class AddressSelectionScreen extends StatefulWidget {
  final String token;
  final String customerId;
  final double deliveryFee;
  final double finalTotal;

  const AddressSelectionScreen({
    super.key,
    required this.token,
    required this.customerId,
    this.deliveryFee = 0,
    this.finalTotal = 0,
  });
  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  List<AddressModel> _addresses = [];
  bool _loading = true;

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

  // ✅ Pass token + customerId, reload on return
  Future<void> _goToAddAddress() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(
          token:      widget.token,
          customerId: widget.customerId,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  // ✅ No local storage — just navigate to payment

  void _selectAddress(AddressModel address) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(
          selectedAddress: address,
          deliveryFee: widget.deliveryFee,
          finalTotal: widget.finalTotal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black45),
          onPressed: () => Navigator.pop(context),
        ),
        title:  Padding(
          padding: const EdgeInsets.only(right: 60),
          child: Text('Choose Address',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Orange header ──────────────────────────────────────────────

          const SizedBox.shrink(),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ?
            const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF0080)))
                : RefreshableScreen(
              onRefresh: _load,
              color: const Color(0xFFFF0080),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [


                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'Select a saved address',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),

                  // ✅ Address cards from API
                  if (_addresses.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _addresses.length,
                      itemBuilder: (_, i) => _AddressCard(
                        address:  _addresses[i],
                        onSelect: () => _selectAddress(_addresses[i]),
                      ),
                    ),

                  // ✅ Empty state
                  if (_addresses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Text(
                        'No saved addresses. Add one below.',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[500]),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Add new address
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _goToAddAddress,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF0080), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('+ Add new address',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF0080))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text('or',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to cart',
                          style: TextStyle(
                              fontSize: 16, color: Color(0xFFFF0080))),
                    ),
                  ),
                  const SizedBox(height: 24),],
                ),
              ),
            ),    // closes RefreshableScreen
          ),
        ],
      ),
    );
  }
}

// ─── Address Card ─────────────────────────────────────────────────────────────
class _AddressCard extends StatelessWidget {
  final AddressModel address;
  final VoidCallback onSelect;

  const _AddressCard({required this.address, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isSelected = address.isDefault;
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFFFF0080) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
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
                border: Border.all(
                    color: isSelected ? const Color(0xFFFF0080) : Colors.grey[400]!,
                    width: 2),
              ),
              child: isSelected
                  ? Center(
                child: Container(
                  width: 9, height: 9,
                  decoration: const BoxDecoration(
                      color: Color(0xFFFF0080),
                      shape: BoxShape.circle),
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
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,),
                    ),
                    if (isSelected)
                      const TextSpan(
                        text: '  (Default Address)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                  ],
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Default',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(address.singleLine,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
              const SizedBox(height: 2),
              Text('Mobile: ${address.phone}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSelect,
                  style: ElevatedButton.styleFrom(

                    backgroundColor: const Color(0xFFFF0080),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Deliver here',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}