import 'package:flutter/material.dart';

import '../config/app_color.dart';

class DeliveryUnavailablePage extends StatelessWidget {
  /// The pincode / address the user entered — shown in the message.
  final String pincode;

  const DeliveryUnavailablePage({super.key, required this.pincode});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Delivery Unavailable',
          style: TextStyle(
            color:       AppColors.appBarText,
            fontWeight: FontWeight.bold,
            fontSize:   18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Illustration container ─────────────────────────────────────
            Container(
              width:  160,
              height: 160,
              decoration: BoxDecoration(
                color:        AppColors.lightBrown.withOpacity(0.08),
                shape:        BoxShape.circle,
                border:       Border.all(
                    color: AppColors.lightBrown.withOpacity(0.18), width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.location_off_rounded,
                      size: 80, color: AppColors.buttonPrimary.withOpacity(0.25)),
                  Positioned(
                    bottom: 28,
                    right:  28,
                    child: Container(
                      padding:    const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color:      Colors.black.withOpacity(0.1),
                                blurRadius: 6)
                          ]),
                      child: const Icon(Icons.close,
                          color: Colors.red, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ── Sorry heading ──────────────────────────────────────────────
            const Text(
              'Sorry, we\'re unable to\ndeliver to this address',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.bold,
                color:      Color(0xFF1A0A00),
                height:     1.35,
              ),
            ),

            const SizedBox(height: 16),

            // ── Pincode chip ───────────────────────────────────────────────
            if (pincode.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:        AppColors.buttonPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(
                      color: AppColors.buttonPrimary.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pin_drop_outlined,
                        size: 16, color: AppColors.buttonPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Pincode: $pincode',
                      style: TextStyle(
                          fontSize:   14,
                          color:      AppColors.appBarText,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ── Subtitle ───────────────────────────────────────────────────
            Text(
              'We haven\'t reached your area yet, but we\'re expanding fast! '
                  'Try a nearby pincode (516269) or check back soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:    Colors.grey[600],
                height:   1.55,
              ),
            ),

            const SizedBox(height: 48),

            // ── Try a different address ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  // Pop back to location selection
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Try a Different Address',
                  style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.bold,
                    color:      Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Go back home (skip) ────────────────────────────────────────
            TextButton(
              onPressed: () {
                // Pop everything back to root / home
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(
                'Go back to home',
                style: TextStyle(
                    fontSize:   14,
                    color:      AppColors.buttonPrimary,
                    decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}