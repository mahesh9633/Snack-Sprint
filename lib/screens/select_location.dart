import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_new_address.dart';

// ── Data model for a selected address ────────────────────────────────────────
class SelectedAddress {
  final String label;
  final String subtitle;
  final double? latitude;
  final double? longitude;
  final String? mapsLink;

  const SelectedAddress({
    required this.label,
    required this.subtitle,
    this.latitude,
    this.longitude,
    this.mapsLink,
  });
}

class _RecentAddress {
  final String label;
  final String subtitle;
  final IconData icon;
  final double? latitude;
  final double? longitude;

  const _RecentAddress({
    required this.label,
    required this.subtitle,
    required this.icon,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'label':     label,
    'subtitle':  subtitle,
    'iconCode':  icon.codePoint,
    'latitude':  latitude,
    'longitude': longitude,
  };

  factory _RecentAddress.fromJson(Map<String, dynamic> j) => _RecentAddress(
    label:     j['label']    as String,
    subtitle:  j['subtitle'] as String,
    icon:      IconData(j['iconCode'] as int, fontFamily: 'MaterialIcons'),
    latitude:  (j['latitude']  as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
  );
}

const _kMaxRecent = 5;

String _prefsKey(String token) => 'recent_addresses_$token';

Future<List<_RecentAddress>> _loadRecentAddresses(String token) async {
  final prefs = await SharedPreferences.getInstance();
  final raw   = prefs.getStringList(_prefsKey(token)) ?? [];
  return raw
      .map((s) => _RecentAddress.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();
}

Future<void> _saveRecentAddress(_RecentAddress addr, String token) async {
  final prefs   = await SharedPreferences.getInstance();
  final current = await _loadRecentAddresses(token);

  current.removeWhere(
          (r) => r.label == addr.label && r.subtitle == addr.subtitle);

  current.insert(0, addr);
  final trimmed = current.take(_kMaxRecent).toList();

  await prefs.setStringList(
    _prefsKey(token),
    trimmed.map((r) => jsonEncode(r.toJson())).toList(),
  );
}

class SelectLocationScreen extends StatefulWidget {
  final void Function(SelectedAddress) onAddressConfirmed;
  final String token;

  const SelectLocationScreen({super.key, required this.onAddressConfirmed, required this.token});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _darkBrown = Color(0xFF3D1F00);
  static const Color _accent    = Color(0xFFB85C00);
  static const Color _cream     = Color(0xFFFDF6EC);
  static const Color _mutedText = Color(0xFFD9C4A8);

  bool _locLoading = false;

  List<_RecentAddress> _recentAddresses = [];
  bool _recentLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await _loadRecentAddresses(widget.token);
    if (mounted) {
      setState(() {
        _recentAddresses = list;
        _recentLoading   = false;
      });
    }
  }

  void dispose() {
    super.dispose();
  }

  // ── Get GPS location ───────────────────────────────────────────────────────
  Future<void> _useCurrentLocation() async {
    setState(() => _locLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        _showPermissionDialog();
        setState(() => _locLoading = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = placemarks.isNotEmpty ? placemarks.first : null;

      final label   = p?.subLocality?.isNotEmpty == true
          ? p!.subLocality!
          : (p?.locality ?? 'Current Location');
      final subtitle = [
        p?.street,
        p?.subLocality,
        p?.locality,
        p?.postalCode,
      ].where((s) => s != null && s.isNotEmpty).join(', ');

      if (!mounted) return;
      setState(() => _locLoading = false);

      final addr = SelectedAddress(
        label:     label,
        subtitle:  subtitle.isNotEmpty ? subtitle : 'Your current location',
        latitude:  pos.latitude,
        longitude: pos.longitude,
        mapsLink:  'https://www.google.com/maps/dir/?api=1&destination=${pos.latitude},${pos.longitude}&travelmode=driving',
      );
      await _saveRecentAddress(_RecentAddress(
        label:     label,
        subtitle:  subtitle.isNotEmpty ? subtitle : 'Your current location',
        icon:      Icons.my_location,
        latitude:  pos.latitude,
        longitude: pos.longitude,
      ), widget.token);
      widget.onAddressConfirmed(addr);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _locLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Could not get location: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   const Text('Location Permission'),
        content: const Text(
            'Location permission is required to use your current location. '
                'Please enable it in app settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Navigate to Add New Address ────────────────────────────────────────────
  void _openAddNewAddress() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNewAddressScreen(
          token: widget.token,
          onAddressConfirmed: (addr) async {
            final icon = addr.label == 'WORK'
                ? Icons.work
                : addr.label == 'HOME'
                ? Icons.home
                : Icons.location_on;
            await _saveRecentAddress(_RecentAddress(
              label:     addr.label,
              subtitle:  addr.subtitle,
              icon:      icon,
              latitude:  addr.latitude,
              longitude: addr.longitude,
            ), widget.token);
            widget.onAddressConfirmed(addr);
            Navigator.of(context)
              ..pop()
              ..pop();
          },
        ),
      ),
    );
  }

  void _selectRecent(_RecentAddress r) async {
    await _saveRecentAddress(r, widget.token);
    final addr = SelectedAddress(
      label:     r.label,
      subtitle:  r.subtitle,
      latitude:  r.latitude,
      longitude: r.longitude,
      mapsLink:  r.latitude != null && r.longitude != null
          ? 'https://www.google.com/maps/dir/?api=1&destination=${r.latitude},${r.longitude}&travelmode=driving'
          : null,
    );
    widget.onAddressConfirmed(addr);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFDF6EC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize:        MainAxisSize.min,
        crossAxisAlignment:  CrossAxisAlignment.start,
        children: [

          const SizedBox(height: 16),

          // ── Current + Add grid ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              // Current Location button
              Expanded(
                child: GestureDetector(
                  onTap: _locLoading ? null : _useCurrentLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color:        _accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(children: [
                      _locLoading
                          ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : Container(
                        width:  36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
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
              // Add address button
              Expanded(
                child: GestureDetector(
                  onTap: _openAddNewAddress,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border:       Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(children: [
                      Container(
                        width:  36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add,
                            color: Colors.grey[700], size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text('+ Add address',
                          style: TextStyle(
                              fontSize:   12,
                              fontWeight: FontWeight.bold,
                              color:      Colors.grey[700])),
                    ]),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Recent Addresses label ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Recent Addresses',
              style: TextStyle(
                fontSize:      13,
                fontWeight:    FontWeight.w600,
                color:         Colors.grey[500],
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Recent list ────────────────────────────────────────────────────
          if (_recentLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:       Color(0xFFB85C00)),
              ),
            )
          else if (_recentAddresses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Text(
                'No recent addresses yet.',
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              ),
            )
          else
            LimitedBox(
              maxHeight: 280,
              child: ListView.separated(
                shrinkWrap: true,
                physics:    const NeverScrollableScrollPhysics(),
                padding:    const EdgeInsets.symmetric(horizontal: 16),
                itemCount:  _recentAddresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final r = _recentAddresses[i];
                  return _RecentTile(r: r, onTap: () => _selectRecent(r));
                },
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Recent address tile ──────────────────────────────────────────────────────
class _RecentTile extends StatelessWidget {
  final _RecentAddress r;
  final VoidCallback   onTap;
  const _RecentTile({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset:     const Offset(0, 1))
          ],
        ),
        child: Row(children: [
          Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
                color:        Colors.grey[100],
                borderRadius: BorderRadius.circular(10)),
            child: Icon(r.icon, color: Colors.grey[600], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.label,
                    style: const TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.bold,
                        color:      Colors.black87)),
                const SizedBox(height: 3),
                Text(r.subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}