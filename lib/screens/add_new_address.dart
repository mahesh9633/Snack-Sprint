import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:mtl_groceriesapp/screens/select_location.dart';

import '../config/app_color.dart';
import '../services/pincode_service.dart';
import '../services/pincode_zone_check_service.dart';

class AddNewAddressScreen extends StatefulWidget {
  final void Function(SelectedAddress) onAddressConfirmed;
  final String token;

  const AddNewAddressScreen({super.key, required this.onAddressConfirmed, required this.token});

  @override
  State<AddNewAddressScreen> createState() => _AddNewAddressScreenState();
}

class _AddNewAddressScreenState extends State<AddNewAddressScreen> {

  // ── Controllers ────────────────────────────────────────────────────────────
  final TextEditingController _pincodeCtrl  = TextEditingController();
  final TextEditingController _flatCtrl     = TextEditingController();
  final TextEditingController _areaCtrl     = TextEditingController();
  final TextEditingController _landmarkCtrl = TextEditingController();
  final FocusNode             _pincodeFocus = FocusNode();

  // ── Map ────────────────────────────────────────────────────────────────────
  final MapController _mapCtrl = MapController();
  LatLng _pin = const LatLng(14.0446, 78.7432); // default: Rayachoty

  // ── Pincode state ──────────────────────────────────────────────────────────
  bool   _pincodeLoading = false;
  String _pincodeError   = '';
  String _resolvedCity    = '';
  String _resolvedState   = '';
  String _resolvedArea    = '';
  Timer? _debounce;

  // ── Save state ─────────────────────────────────────────────────────────────
  bool   _saving       = false;
  String _saveError    = '';

  // ── Label selection ────────────────────────────────────────────────────────
  String _selectedLabel = 'HOME';
  final List<Map<String, dynamic>> _labels = [
    {'label': 'HOME',  'icon': Icons.home},
    {'label': 'WORK',  'icon': Icons.work},
    {'label': 'OTHER', 'icon': Icons.location_on},
  ];

  @override
  void initState() {
    super.initState();
    _tryGetCurrentLocation();
    _pincodeCtrl.addListener(_onPincodeChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pincodeCtrl.dispose();
    _flatCtrl.dispose();
    _areaCtrl.dispose();
    _landmarkCtrl.dispose();
    _pincodeFocus.dispose();
    super.dispose();
  }

  // ── Try to get GPS location for map center ─────────────────────────────────
  Future<void> _tryGetCurrentLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      if (!mounted) return;
      setState(() => _pin = LatLng(pos.latitude, pos.longitude));
      _mapCtrl.move(_pin, 15);
    } catch (_) {}
  }

  // ── Re-center map to GPS ───────────────────────────────────────────────────
  Future<void> _recenterMap() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _pin = LatLng(pos.latitude, pos.longitude));
      _mapCtrl.move(_pin, 16);
    } catch (_) {}
  }

  // ── Pincode auto-search with debounce ─────────────────────────────────────
  void _onPincodeChanged() {
    final text = _pincodeCtrl.text.trim();
    setState(() {
      _pincodeError = '';
      if (text.length < 6) {
        _resolvedCity  = '';
        _resolvedState = '';
        _resolvedArea  = '';
      }
    });
    _debounce?.cancel();
    if (text.length == 6) {
      _debounce = Timer(const Duration(milliseconds: 600), () => _lookupPincode(text));
    }
  }

  Future<void> _lookupPincode(String pin) async {
    setState(() { _pincodeLoading = true; _pincodeError = ''; });
    final result = await PincodeService.lookup(pin);
    if (!mounted) return;
    if (result.isSuccess) {
      // Try geocoding the pincode to move the map
      _geocodePincode(pin, result.city, result.state);

      setState(() {
        _pincodeLoading = false;
        _resolvedArea   = result.area;
        _resolvedCity   = result.city;
        _resolvedState  = result.state;
        // Auto-fill area field if empty
        if (_areaCtrl.text.isEmpty) {
          _areaCtrl.text = result.area;
        }
      });
    } else {
      setState(() {
        _pincodeLoading = false;
        _pincodeError   = result.error;
        _resolvedCity   = '';
        _resolvedState  = '';
        _resolvedArea   = '';
      });
    }
  }

  Future<void> _geocodePincode(String pin, String city, String state) async {
    try {
      final locs = await locationFromAddress('$pin, $city, $state, India');
      if (locs.isNotEmpty && mounted) {
        final newPin = LatLng(locs.first.latitude, locs.first.longitude);
        setState(() => _pin = newPin);
        _mapCtrl.move(newPin, 14);
      }
    } catch (_) {}
  }

  // ── Manual search button ───────────────────────────────────────────────────
  void _onSearchPressed() {
    final pin = _pincodeCtrl.text.trim();
    if (pin.length == 6) {
      _lookupPincode(pin);
    } else {
      setState(() => _pincodeError = 'Enter a valid 6-digit pincode');
    }
  }

  // ── Confirm & Save ─────────────────────────────────────────────────────────
  Future<void> _confirmAndSave() async {
    final pincode  = _pincodeCtrl.text.trim();
    final flatNo   = _flatCtrl.text.trim();
    final area     = _areaCtrl.text.trim();

    // Basic validation
    if (pincode.length != 6) {
      setState(() => _saveError = 'Please enter a valid 6-digit pincode.');
      return;
    }
    if (flatNo.isEmpty) {
      setState(() => _saveError = 'Please enter your flat / house / building no.');
      return;
    }
    if (_resolvedCity.isEmpty) {
      // pincode not yet verified — do it now
      setState(() { _saving = true; _saveError = ''; });
      final result = await PincodeService.lookup(pincode);
      if (!mounted) return;
      if (!result.isSuccess) {
        setState(() {
          _saving     = false;
          _saveError  = 'Invalid pincode: ${result.error}';
        });
        return;
      }
      setState(() {
        _resolvedCity  = result.city;
        _resolvedState = result.state;
        _resolvedArea  = result.area;
      });
    }

    setState(() { _saving = true; _saveError = ''; });

    // ── Zone check ────────────────────────────────────────────────────────
    final zoneResult = await ZoneCheckService.check(
      postcode: pincode,
      token:    widget.token,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (zoneResult.hasError) {
      setState(() => _saveError = 'Could not verify delivery zone: ${zoneResult.error}');
      return;
    }

    if (!zoneResult.available) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    Icon(Icons.location_off_rounded,
                        size: 44, color: Colors.red.withOpacity(0.3)),
                    Positioned(
                      bottom: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.red, size: 14),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delivery Unavailable',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.pin_drop_outlined, size: 14, color: Colors.red),
                    const SizedBox(width: 5),
                    Text('Pincode: $pincode',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.red,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(
                  "Sorry, we're unable to deliver to this address. "
                      "We haven't reached your area yet, but we're expanding fast!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[600], height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:  AppColors.buttonPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Try a Different Pincode',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // ── Zone OK → confirm address ─────────────────────────────────────────
    final String tracking =
        'https://www.google.com/maps/dir/?api=1&destination=${_pin.latitude},${_pin.longitude}&travelmode=driving';
    final subtitle = [flatNo, area.isNotEmpty ? area : _resolvedArea,
      _resolvedCity, _resolvedState, pincode]
        .where((s) => s.isNotEmpty)
        .join(', ');

    widget.onAddressConfirmed(SelectedAddress(
      label:     _selectedLabel,
      subtitle:  subtitle,
      latitude:  _pin.latitude,
      longitude: _pin.longitude,
      mapsLink:  tracking,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:  AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add New Address',
            style: TextStyle(
                color: AppColors.appBarText,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Pincode section ───────────────────────────────────────────────
          _sectionLabel('Pincode'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _pincodeError.isNotEmpty
                        ? Colors.red
                        : AppColors.border,
                  ),
                ),
                child: Row(children: [
                  const SizedBox(width: 14),
                  Icon(Icons.location_on_outlined,
                      color: Colors.grey[400], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller:   _pincodeCtrl,
                      focusNode:    _pincodeFocus,
                      keyboardType: TextInputType.number,
                      maxLength:    6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText:    'Enter 6-digit pincode',
                        hintStyle:
                        TextStyle(color: Colors.grey[400], fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_pincodeLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.loader),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            // Search button
            GestureDetector(
              onTap: _onSearchPressed,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: AppColors.buttonPrimary,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.search, color: Colors.white, size: 24),
              ),
            ),
          ]),

          // Pincode result or error
          if (_pincodeError.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              // Icon(Icons.error_outline, color: Colors.red[400], size: 14),
              Icon(Icons.error_outline, color: AppColors.error, size: 14),
              const SizedBox(width: 6),
              Text(_pincodeError,
                  // style: TextStyle(color: Colors.red[400], fontSize: 12)),
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ]),
          ],
          if (_resolvedCity.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF388E3C), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_resolvedArea, $_resolvedCity, $_resolvedState',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          // ── Map ───────────────────────────────────────────────────────────
          _sectionLabel('Pin your exact location'),
          const SizedBox(height: 4),
          Text(
            'Tap anywhere on the map to move the delivery pin',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: Stack(children: [
                FlutterMap(
                  mapController: _mapCtrl,

                  options: MapOptions(
                    initialCenter: _pin,
                    initialZoom:   15.0,
                    onTap: (tapPos, latlng) {
                      setState(() => _pin = latlng);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.dbm.mtl_groceriesapp',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point:  _pin,
                          width:  48,
                          height: 48,
                          child: const Icon(Icons.location_pin,
                              // color: _pink, size: 48),
                              color: AppColors.buttonPrimary, size: 48),
                        ),
                      ],
                    ),
                  ],
                ),

                // Re-center button
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _recenterMap,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6)
                          ]),
                      child: const Icon(Icons.my_location,
                          color: AppColors.buttonPrimary, size: 20),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // ── Flat / House / Building No. ───────────────────────────────────
          _sectionLabel('Flat / House / Building No.'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _flatCtrl,
            hint:       'e.g. Flat 4B, Rose Apartments',
            icon:       Icons.home_outlined,
          ),

          const SizedBox(height: 16),

          // ── Area / Street / Locality ──────────────────────────────────────
          _sectionLabel('Area / Street / Locality'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _areaCtrl,
            hint:       'e.g. MVP Colony, Sector 7',
            icon:       Icons.map_outlined,
          ),

          const SizedBox(height: 16),

          // ── Landmark (optional) ───────────────────────────────────────────
          _sectionLabel('Landmark (Optional)'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _landmarkCtrl,
            hint:       'e.g. Near City Hospital',
            icon:       Icons.flag_outlined,
          ),

          const SizedBox(height: 20),

          // ── Label ─────────────────────────────────────────────────────────
          _sectionLabel('Save As'),
          const SizedBox(height: 10),
          Row(children: _labels.map((l) {
            final isSelected = _selectedLabel == l['label'];
            return GestureDetector(
              onTap: () => setState(() => _selectedLabel = l['label']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 10),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:        isSelected ? AppColors.lightBrown : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.lightBrown : AppColors.border,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(
                      color: AppColors.lightBrown.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3))]
                      : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(l['icon'] as IconData,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 16),
                  const SizedBox(width: 6),
                  Text(l['label'] as String,
                      style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.grey[700])),
                ]),
              ),
            );
          }).toList()),

          // ── Save error ────────────────────────────────────────────────────
          if (_saveError.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(children: [
                Icon(Icons.error_outline, color: Colors.red[400], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_saveError,
                      style:
                      TextStyle(color: Colors.red[700], fontSize: 13)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 28),
        ]),
      ),

      // ── Confirm & Save button ─────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _confirmAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                disabledBackgroundColor:  AppColors.buttonPrimaryDisabled,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: AppColors.buttonPrimary.withOpacity(0.4),
              ),
              child: _saving
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
                  : const Text(
                'Confirm & Save Address',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(icon, color: Colors.grey[400], size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white, fontSize: 13),
              border:         InputBorder.none,
              isDense:        true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 14),
      ]),
    );
  }
}