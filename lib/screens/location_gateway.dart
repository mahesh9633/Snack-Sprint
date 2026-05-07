import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/config/app_color.dart';
import 'package:mtl_groceriesapp/screens/select_location_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LocationGateway extends StatelessWidget {
  final String  telephone;
  final bool    isNewCustomer;
  final String? authToken;
  final String  customerId;

  const LocationGateway({
    super.key,
    required this.telephone,
    required this.customerId,
    this.isNewCustomer = false,
    this.authToken,
  });

  Future<void> _saveAndGoHome(BuildContext context, SelectedAddress addr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('address_confirmed', true);
    await prefs.setString('saved_address_label',    addr.label);
    await prefs.setString('saved_address_subtitle', addr.subtitle);
    if (addr.lat != null) await prefs.setDouble('saved_address_lat', addr.lat!);
    if (addr.lng != null) await prefs.setDouble('saved_address_lng', addr.lng!);

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          telephone:     telephone,
          isNewCustomer: isNewCustomer,
          authToken:     authToken,
          customerId:    customerId,
        ),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(children: [

          // ── Top branding strip ───────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delivery_dining,
                        color: AppColors.buttonPrimary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Durga Bhavani Mart',
                      style: TextStyle(
                          fontSize:   26,
                          fontWeight: FontWeight.bold,
                          fontStyle:  FontStyle.italic,
                          color:      AppColors.lightBrown)),
                ]),
              ],
            ),
          ),

          // ── SelectLocationSheet embedded ─────────────────────────────
          Expanded(
            child: SelectLocationSheet(
              onUseCurrentLocation: (addr) => _saveAndGoHome(context, addr),
              onAddressSelected:    (addr) => _saveAndGoHome(context, addr),
            ),
          ),

          // ── Skip option ──────────────────────────────────────────────
          TextButton(
            onPressed: () {
              showDialog(
                context:           context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  backgroundColor: AppColors.white,
                  icon: const Icon(Icons.location_off_outlined,
                      color: AppColors.buttonPrimary, size: 48),
                  title: const Text(
                    'Location Required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:      AppColors.sectionHeader,
                        fontSize:   18),
                  ),
                  content: const Text(
                    'Please select a delivery location to continue.\n\nWe need your address to deliver products to you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                      child: const Text(
                        'Select Location',
                        style: TextStyle(
                            color:      Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back,
                          size: 16, color: Colors.grey),
                      label: const Text('Go Back',
                          style: TextStyle(color: Colors.black87, fontSize: 13)),
                    ),
                  ],
                ),
              );
            },
            child: Text(
              'Skip for now',
              style: TextStyle(
                  fontSize:   13,
                  color:      Colors.pink,
                  decoration: TextDecoration.underline),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}