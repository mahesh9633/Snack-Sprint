import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtl_groceriesapp/config/app_color.dart';

import '../services/pincode_service.dart';
import '../services/pincode_zone_check_service.dart';
import 'delivery_unavailable_screen.dart';

String get _authToken {
  return '6dd01c52d3e107b179798efc3716354bcc4c0d2b8e6f3a1d5e9c2b7a4f8e0d3c';
}

class SelectedAddress {
  final String  label;
  final String  subtitle;
  final double? lat;
  final double? lng;
  final String? pincode;
  final String? flat;
  final String? area;
  final String? mapsLink;

  const SelectedAddress({
    required this.label,
    required this.subtitle,
    this.lat,
    this.lng,
    this.pincode,
    this.flat,
    this.area,
    this.mapsLink,
  });
}

class SelectLocationSheet extends StatefulWidget {
  final void Function(SelectedAddress address) onUseCurrentLocation;
  final void Function(SelectedAddress address) onAddressSelected;

  final bool showBackButton;

  const SelectLocationSheet({
    super.key,
    required this.onUseCurrentLocation,
    required this.onAddressSelected,
    this.showBackButton = true,
  });

  @override
  State<SelectLocationSheet> createState() => _SelectLocationSheetState();
}

class _SelectLocationSheetState extends State<SelectLocationSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  String _searchQuery     = '';
  bool   _locationLoading = false;

  static const _kPrefsKey  = 'recent_addresses_v2';
  static const _kMaxRecent = 8;

  List<Map<String, String>> _recentAddresses = [];
  bool _recentLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentAddresses();
  }

  Future<void> _loadRecentAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_kPrefsKey) ?? [];
    final list  = raw
        .map((s) => Map<String, String>.from(jsonDecode(s) as Map))
        .toList();
    if (mounted) {
      setState(() {
        _recentAddresses = list;
        _recentLoading   = false;
      });
    }
  }

  Future<void> _saveToRecent(Map<String, String> addr) async {
    final prefs   = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_kPrefsKey) ?? [])
        .map((s) => Map<String, String>.from(jsonDecode(s) as Map))
        .toList();
    current.removeWhere(
            (r) => r['title'] == addr['title'] && r['subtitle'] == addr['subtitle']);
    current.insert(0, addr);
    final trimmed = current.take(_kMaxRecent).toList();
    await prefs.setStringList(
        _kPrefsKey, trimmed.map((r) => jsonEncode(r)).toList());
    if (mounted) setState(() => _recentAddresses = trimmed);
  }

  Future<void> _checkZoneAndProceed({
    required String          pincode,
    required SelectedAddress address,
    required VoidCallback    onAvailable,
  }) async {
    if (!mounted) return;
    showDialog(
      context:            context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.buttonPrimary),
      ),
    );

    final result = await ZoneCheckService.check(
      postcode: pincode,
      token:    _authToken,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (result.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('Zone check failed: ${result.error}'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    if (!result.available) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryUnavailablePage(pincode: pincode),
        ),
      );
      return;
    }

    await _saveToRecent({
      'label':    address.label,
      'title':    address.label,
      'subtitle': address.subtitle,
      if (address.pincode != null && address.pincode!.isNotEmpty)
        'pincode': address.pincode!,
    });
    onAvailable();
  }

  // ── Current location flow ──────────────────────────────────────────────────
  Future<void> _handleCurrentLocation() async {
    setState(() => _locationLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        _showPermissionDeniedDialog();
        setState(() => _locationLoading = false);
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        setState(() => _locationLoading = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = placemarks.isNotEmpty ? placemarks.first : null;

      String addressLine = '';
      String pincode     = '';
      if (p != null) {
        final parts = [
          p.name,
          p.subLocality,
          p.locality,
          p.administrativeArea
        ].where((s) => s != null && s!.isNotEmpty).toList();
        addressLine = parts.join(', ');
        pincode     = p.postalCode ?? '';
        if (pincode.isNotEmpty) addressLine += ' $pincode';
      } else {
        addressLine =
        '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      }

      if (!mounted) return;
      setState(() => _locationLoading = false);

      _showLocationConfirmSheet(
        context:     context,
        addressLine: addressLine,
        lat:         pos.latitude,
        lng:         pos.longitude,
        pincode:     pincode,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _locationLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Could not fetch location: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _showLocationConfirmSheet({
    required BuildContext context,
    required String addressLine,
    required double lat,
    required double lng,
    required String pincode,
  }) {
    showModalBottomSheet(
      context:       context,
      isDismissible: false,
      enableDrag:    false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.buttonPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location,
                    color: AppColors.buttonPrimary, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Deliver to this location?',
                  style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.bold,
                      color:      Colors.black87)),
            ]),
            const SizedBox(height: 16),
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on,
                      color: AppColors.buttonPrimary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(addressLine,
                        style: const TextStyle(
                            fontSize: 14,
                            color:    Colors.black87,
                            height:   1.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.buttonPrimary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Change',
                      style: TextStyle(
                          color:      AppColors.buttonPrimary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);

                    final address = SelectedAddress(
                      label:    'CURRENT',
                      subtitle: addressLine,
                      lat:      lat,
                      lng:      lng,
                      pincode:  pincode,
                    );

                    await _checkZoneAndProceed(
                      pincode:     pincode,
                      address:     address,
                      onAvailable: () {
                        widget.onUseCurrentLocation(address);
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:   const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text('Confirm Location',
                      style: TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize:   15)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Location Permission'),
        content: const Text(
            'Location permission is required. Please enable it in app settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              child: const Text('Open Settings')),
        ],
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Location Service Off'),
        content: const Text(
            'Please enable location services on your device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings')),
        ],
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color:        AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // ── Dark Brown Header ──────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color:       AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width:  40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color:        Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (widget.showBackButton)
                    GestureDetector(
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.arrow_back,
                          color: AppColors.appBarIcon,
                          size: 22,
                        ),
                      ),
                    ),

                  const Text(
                    'Where should we deliver?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.appBarText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: _buildDefaultOptions(),
        ),
      ]),
    );
  }

  Widget _buildDefaultOptions() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(children: [
          // Current Location button
          Expanded(
            child: GestureDetector(
              onTap: _locationLoading ? null : _handleCurrentLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color:        AppColors.headerBanner,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  _locationLoading
                      ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : Container(
                    width:  36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.my_location,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 8),
                  const Text('Current location',
                      style: TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.bold,
                          color:      Colors.white)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Check Delivery button
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push<SelectedAddress>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddNewAddressPage()));
                if (result != null && mounted) {
                  await _saveToRecent({
                    'label':    result.label,
                    'title':    result.flat?.isNotEmpty == true
                        ? result.flat!
                        : result.label,
                    'subtitle': result.subtitle,
                    if (result.pincode != null && result.pincode!.isNotEmpty)
                      'pincode': result.pincode!,
                    if (result.flat != null && result.flat!.isNotEmpty)
                      'flat': result.flat!,
                    if (result.area != null && result.area!.isNotEmpty)
                      'area': result.area!,
                    if (result.mapsLink != null && result.mapsLink!.isNotEmpty)
                      'mapsLink': result.mapsLink!,
                  });
                  widget.onAddressSelected(result);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: AppColors.border),
                ),
                child: Column(children: [
                  Container(
                    width:  36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.search,
                        color: Colors.grey[700], size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text('Check Delivery',
                      style: TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.bold,
                          color:      Colors.grey[700])),
                ]),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 20),

        Text('Recent addresses',
            style: TextStyle(
                fontSize:      13,
                fontWeight:    FontWeight.w600,
                color:         Colors.black87,
                letterSpacing: 0.3)),
        const SizedBox(height: 10),

        if (_recentLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.buttonPrimary),
            ),
          )
        else if (_recentAddresses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No recent addresses yet.',
                style: TextStyle(fontSize: 13, color: Colors.black87)),
          )
        else
          ..._recentAddresses.map((a) => _addressTile(a)).toList(),
      ],
    );
  }

  Widget _addressTile(Map<String, String> addr, {bool inCard = false}) {
    Widget tile = InkWell(
      onTap: () async {
        final pincode = addr['pincode'] ?? '';

        final address = SelectedAddress(
          label:    addr['label'] ?? addr['title'] ?? '',
          subtitle: addr['subtitle'] ?? '',
          pincode:  pincode.isNotEmpty ? pincode : null,
        );

        if (pincode.length == 6) {
          await _checkZoneAndProceed(
            pincode:     pincode,
            address:     address,
            onAvailable: () => widget.onAddressSelected(address),
          );
        } else {
          await _saveToRecent(addr);
          widget.onAddressSelected(address);
        }
      },
      borderRadius:
      inCard ? BorderRadius.zero : BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
                color:        AppColors.white,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
              addr['label'] == 'HOME'
                  ? Icons.home
                  : addr['label'] == 'WORK'
                  ? Icons.work
                  : Icons.location_on,
              color: Colors.grey[600],
              size:  20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(addr['title'] ?? addr['label'] ?? '',
                    style: const TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.bold,
                        color:      Colors.black87)),
                const SizedBox(height: 3),
                Text(addr['subtitle'] ?? '',
                    style:    TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );

    if (inCard) return tile;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset:     const Offset(0, 1))
          ]),
      child: tile,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class AddNewAddressPage extends StatefulWidget {
  const AddNewAddressPage({super.key});

  @override
  State<AddNewAddressPage> createState() => _AddNewAddressPageState();
}

class _AddNewAddressPageState extends State<AddNewAddressPage> {
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _flatController    = TextEditingController();
  final TextEditingController _areaController    = TextEditingController();
  final MapController         _mapController     = MapController();

  bool   _pincodeLoading = false;
  String _pincodeError   = '';
  String _resolvedArea   = '';
  String _resolvedCity   = '';
  String _resolvedState  = '';

  LatLng _markerPosition = const LatLng(14.0446, 78.7432);
  bool   _addressLoading = false;
  String _selectedLabel  = 'HOME';
  final List<String> _labels = ['HOME', 'WORK', 'OTHER'];

  Future<void> _searchPincode(String pin) async {
    if (pin.length != 6) return;
    setState(() {
      _pincodeLoading = true;
      _pincodeError   = '';
      _resolvedArea   = '';
    });

    final zoneResult = await ZoneCheckService.check(
      postcode: pin,
      token:    _authToken,
    );

    if (!mounted) return;

    if (zoneResult.hasError || !zoneResult.available) {
      setState(() => _pincodeLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryUnavailablePage(pincode: pin),
        ),
      );
      return;
    }

    final result = await PincodeService.lookup(pin);
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _pincodeError   = result.error;
        _pincodeLoading = false;
      });
      return;
    }

    try {
      final locations = await locationFromAddress(
          '${result.pincode}, ${result.city}, ${result.state}, India');
      if (locations.isNotEmpty && mounted) {
        final newPos =
        LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          _markerPosition = newPos;
          _resolvedArea   = result.area;
          _resolvedCity   = result.city;
          _resolvedState  = result.state;
          _pincodeLoading = false;
          if (_areaController.text.isEmpty) {
            _areaController.text = '${result.area}, ${result.city}';
          }
        });
        _mapController.move(newPos, 15.0);
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _resolvedArea   = result.area;
        _resolvedCity   = result.city;
        _resolvedState  = result.state;
        _pincodeLoading = false;
        if (_areaController.text.isEmpty) {
          _areaController.text = '${result.area}, ${result.city}';
        }
      });
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _addressLoading = true);
    try {
      final placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final p       = placemarks.first;
        final pincode = p.postalCode ?? '';
        setState(() {
          _resolvedCity  = p.locality           ?? _resolvedCity;
          _resolvedState = p.administrativeArea ?? _resolvedState;
          if (pincode.isNotEmpty) {
            _pincodeController.text = pincode;
            _resolvedArea = '${p.subLocality ?? ''}, ${p.locality ?? ''}'
                .trim()
                .replaceAll(RegExp(r'^,|,$'), '');
          }
          final areaText = [p.name, p.subLocality, p.locality]
              .where((s) => s != null && s!.isNotEmpty)
              .join(', ');
          if (areaText.isNotEmpty) _areaController.text = areaText;
          _addressLoading = false;
        });
      } else {
        setState(() => _addressLoading = false);
      }
    } catch (_) {
      setState(() => _addressLoading = false);
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) return;

      final pos    = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() => _markerPosition = newPos);
      _mapController.move(newPos, 16.0);
      _reverseGeocode(newPos);
    } catch (_) {}
  }

  Future<void> _confirmAddress() async {
    final flat = _flatController.text.trim();
    final area = _areaController.text.trim();
    final pin  = _pincodeController.text.trim();

    if (area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter area/street')));
      return;
    }
    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter a valid 6-digit pincode')));
      return;
    }

    showDialog(
      context:            context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.buttonPrimary),
      ),
    );

    final zoneResult = await ZoneCheckService.check(
      postcode: pin,
      token:    _authToken,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (zoneResult.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('Zone check failed: ${zoneResult.error}'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    if (!zoneResult.available) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryUnavailablePage(pincode: pin),
        ),
      );
      return;
    }

    final fullAddress =
    '$flat, $area, $_resolvedCity, $_resolvedState $pin'
        .trim()
        .replaceAll(RegExp(r',\s*,'), ',')
        .replaceAll(RegExp(r',\s*$'), '');

    final String mapsLink =
        'https://www.google.com/maps/dir/?api=1&destination=${_markerPosition.latitude},${_markerPosition.longitude}&travelmode=driving';
    Navigator.pop(
      context,
      SelectedAddress(
        label:    _selectedLabel,
        subtitle: fullAddress,
        lat:      _markerPosition.latitude,
        lng:      _markerPosition.longitude,
        pincode:  pin,
        flat:     flat,
        area:     area,
        mapsLink: mapsLink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add New Address',
            style: TextStyle(
                color:      Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize:   18)),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _sectionLabel('Pincode'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color:      Colors.black.withOpacity(0.05),
                                blurRadius: 6)
                          ]),
                      child: TextField(
                        controller:      _pincodeController,
                        keyboardType:    TextInputType.number,
                        maxLength:       6,
                        textInputAction: TextInputAction.search,
                        onChanged: (v) {
                          if (v.length == 6) _searchPincode(v);
                          else if (_pincodeError.isNotEmpty) {
                            setState(() => _pincodeError = '');
                          }
                        },
                        onSubmitted: (v) => _searchPincode(v),
                        decoration: InputDecoration(
                          hintText:   'Enter 6-digit pincode',
                          hintStyle:  TextStyle(color: Colors.black87),
                          prefixIcon: const Icon(Icons.pin_drop_outlined,
                              color: AppColors.primaryOrange),
                          counterText:    '',
                          border:         InputBorder.none,
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _searchPincode(_pincodeController.text),
                    child: Container(
                      width:  48,
                      height: 52,
                      decoration: BoxDecoration(
                          color:        AppColors.buttonPrimary,
                          borderRadius: BorderRadius.circular(12)),
                      child: _pincodeLoading
                          ? const Center(
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ))
                          : const Icon(Icons.search, color: Colors.white),
                    ),
                  ),
                ]),

                if (_pincodeError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 16),
                    const SizedBox(width: 6),
                    Text(_pincodeError,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13)),
                  ]),
                ] else if (_resolvedArea.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:        AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            '$_resolvedArea, $_resolvedCity, $_resolvedState',
                            style: const TextStyle(
                                fontSize:   13,
                                color:      AppColors.success,
                                fontWeight: FontWeight.w500)),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                _sectionLabel('Pin your exact location'),
                const SizedBox(height: 4),
                Text('Tap anywhere on the map to move the delivery pin',
                    style:
                    TextStyle(fontSize: 12, color: Colors.black87)),
                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 260,
                    child: Stack(children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _markerPosition,
                          initialZoom:   14.0,
                          onTap: (tapPosition, point) {
                            setState(() => _markerPosition = point);
                            _reverseGeocode(point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.mtl.groceriesapp',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point:  _markerPosition,
                              width:  48,
                              height: 56,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width:  36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color:  AppColors.buttonPrimary,
                                      shape:  BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color:      Colors.black26,
                                            blurRadius: 6,
                                            offset: Offset(0, 3))
                                      ],
                                    ),
                                    child: const Icon(Icons.location_on,
                                        color: Colors.white, size: 22),
                                  ),
                                  CustomPaint(
                                    size:    const Size(14, 10),
                                    painter: _TrianglePainter(),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ],
                      ),
                      Positioned(
                        top: 12, right: 12,
                        child: GestureDetector(
                          onTap: _goToMyLocation,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:        Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6)
                              ],
                            ),
                            child: const Icon(Icons.my_location,
                                color:AppColors.buttonPrimary, size: 22),
                          ),
                        ),
                      ),
                      if (_addressLoading)
                        Positioned(
                          bottom: 12, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  color:        Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8)
                                  ]),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.buttonPrimary),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Getting address…',
                                      style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),

                const SizedBox(height: 20),

                _sectionLabel('Area / Street / Locality'),
                const SizedBox(height: 8),
                _inputField(
                    controller: _areaController,
                    hint:       'e.g. MVP Colony, Sector 7',
                    icon:       Icons.streetview_outlined),
                const SizedBox(height: 20),

                _sectionLabel('Save as'),
                const SizedBox(height: 8),
                Row(
                  children: _labels.map((lbl) {
                    final sel = _selectedLabel == lbl;
                    final ico = lbl == 'HOME'
                        ? Icons.home
                        : lbl == 'WORK'
                        ? Icons.work
                        : Icons.location_on;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedLabel = lbl),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.buttonPrimary : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? AppColors.buttonPrimary
                                : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(ico,
                                size:  16,
                                color: sel
                                    ? Colors.white
                                    : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(lbl,
                                style: TextStyle(
                                    fontSize:   13,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? Colors.white
                                        : Colors.grey[700])),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color:     Colors.white,
            boxShadow: [
              BoxShadow(
                  color:      Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset:     const Offset(0, -3))
            ],
          ),
          child: SizedBox(
            width:  double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _confirmAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Confirm & Save Address',
                  style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.bold,
                      color:      Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize:   14,
          fontWeight: FontWeight.bold,
          color:      Colors.black87));

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) =>
      Container(
        decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color:      Colors.black.withOpacity(0.05),
                  blurRadius: 6)
            ]),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText:   hint,
            hintStyle:  TextStyle(color: Colors.grey[400], fontSize: 13),
            prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
            border:         InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );

  @override
  void dispose() {
    _pincodeController.dispose();
    _flatController.dispose();
    _areaController.dispose();
    super.dispose();
  }
}

// ── lightBrown triangle below the marker circle ────────────────────────────────
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.buttonPrimary;
    final path  = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => false;
}