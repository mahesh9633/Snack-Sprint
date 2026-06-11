import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/config/app_color.dart';
import 'package:mtl_groceriesapp/screens/select_location_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pincode_zone_check_service.dart';
import '../services/session_manager.dart';
import 'home_screen.dart';

class LocationGateway extends StatefulWidget {
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

  @override
  State<LocationGateway> createState() => _LocationGatewayState();
}

class _LocationGatewayState extends State<LocationGateway> {
  bool _checking = true; // show loader while checking saved location

  @override
  void initState() {
    super.initState();
    _checkSavedLocation();
  }

  Future<void> _checkSavedLocation() async {
    final prefs    = await SharedPreferences.getInstance();
    final label    = prefs.getString('saved_address_label')    ?? '';
    final subtitle = prefs.getString('saved_address_subtitle') ?? '';
    final pincode  = prefs.getString('saved_address_pincode')  ?? '';

    // If no saved location, show the sheet normally
    if (label.isEmpty || subtitle.isEmpty) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    // Saved location exists — silently validate zone in background
    if (pincode.length == 6) {
      try {
        final token  = await SessionManager.getToken() ?? '';
        final result = await ZoneCheckService.check(
          postcode: pincode,
          token:    token,
        );
        if (!mounted) return;

        if (!result.hasError && !result.available) {
          // Zone no longer available — clear and show sheet
          await prefs.remove('saved_address_label');
          await prefs.remove('saved_address_subtitle');
          await prefs.remove('saved_address_pincode');
          await prefs.setBool('address_confirmed', false);
          if (mounted) setState(() => _checking = false);
          return;
        }
      } catch (_) {
        // Zone check failed — still allow using saved address
      }
    }

    // Zone valid — go directly to home
    if (!mounted) return;
    _goHome();
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          telephone:     widget.telephone,
          isNewCustomer: widget.isNewCustomer,
          authToken:     widget.authToken,
          customerId:    widget.customerId,
        ),
      ),
          (route) => false,
    );
  }

  Future<void> _saveAndGoHome(SelectedAddress addr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('address_confirmed', true);
    await prefs.setString('saved_address_label',    addr.label);
    await prefs.setString('saved_address_subtitle', addr.subtitle);
    await prefs.setString('saved_address_pincode',  addr.pincode ?? '');
    if (addr.lat != null) await prefs.setDouble('saved_address_lat', addr.lat!);
    if (addr.lng != null) await prefs.setDouble('saved_address_lng', addr.lng!);

    if (!mounted) return;
    _goHome();
  }

  @override
  Widget build(BuildContext context) {
    // Show spinner while checking saved location
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.buttonPrimary),
        ),
      );
    }

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
                  const Text('Smile Basket',
                      style: TextStyle(
                          fontSize:   26,
                          fontWeight: FontWeight.bold,
                          fontStyle:  FontStyle.italic,
                          color:      AppColors.buttonPrimary)),
                ]),
              ],
            ),
          ),

          // ── SelectLocationSheet embedded ─────────────────────────────
          Expanded(
            child: SelectLocationSheet(
              showBackButton: false,
              onUseCurrentLocation: (addr) => _saveAndGoHome(addr),
              onAddressSelected:    (addr) => _saveAndGoHome(addr),
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