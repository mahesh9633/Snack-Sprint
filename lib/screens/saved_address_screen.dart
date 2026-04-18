import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../model/address_model.dart';
import '../services/add_address_service.dart';
import '../services/delete_address_service.dart';
import '../services/edit_address_service.dart';
import '../services/get_address_service.dart';
import '../services/pincode_zone_check_service.dart';
class SavedAddressesScreen extends StatefulWidget {
  final bool   selectMode;
  final String token;
  final String customerId;

  const SavedAddressesScreen({
    super.key,
    this.selectMode = false,
    required this.token,
    required this.customerId,
  });

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<AddressModel> _addresses = [];
  bool               _loading   = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final serverList = await GetAddressApi.getAddresses(token: widget.token);
      if (serverList.isNotEmpty) {
        await AddressStorage.replaceAll(serverList);
        if (mounted) setState(() { _addresses = serverList; _loading = false; });
      } else {
        final localList = await AddressStorage.load();
        if (mounted) setState(() { _addresses = localList; _loading = false; });
      }
    } catch (_) {
      final localList = await AddressStorage.load();
      if (mounted) setState(() { _addresses = localList; _loading = false; });
    }
  }

  Future<void> _selectAddress(AddressModel a) async {
    if (widget.selectMode) {
      Navigator.pop(context, a);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF0080)),
      ),
    );

    final apiResult = await _putAddressToServer(a, forceDefault: true);

    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    if (!apiResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(apiResult.message.isNotEmpty
            ? apiResult.message
            : 'Failed to set default address.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    await AddressStorage.setDefault(a.id);
    setState(() {
      _addresses = _addresses.map((addr) => AddressModel(
        id:           addr.id,
        name:         addr.name,
        fullName:     addr.fullName,
        phone:        addr.phone,
        addressLine1: addr.addressLine1,
        addressLine2: addr.addressLine2,
        city:         addr.city,
        state:        addr.state,
        pinCode:      addr.pinCode,
        isDefault:    addr.id == a.id,
        officeName:   addr.officeName,
        block:        addr.block,
        floor:        addr.floor,
        latitude:     addr.latitude,
        longitude:    addr.longitude,
        tracking:     addr.tracking,
      )).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Default address updated!'),
      backgroundColor: Color(0xFFFF0080),
      behavior: SnackBarBehavior.floating,
    ));
  }
  Future<void> _openForm({AddressModel? existing}) async {
    final willBeFirst = _addresses.isEmpty && existing == null;

    final result = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddressFormScreen(
          existing:     existing,
          forceDefault: !willBeFirst,
          token:        widget.token, // ← pass token for zone check
        ),
      ),
    );

    if (result != null) {
      if (existing == null) {
        final apiResult = await _postAddressToServer(result);
        if (!mounted) return;

        if (!apiResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(apiResult.message.isNotEmpty
                ? apiResult.message : 'Failed to save address.'),
            backgroundColor: Colors.red,
          ));
          return;
        }

        final savedAddress = apiResult.addressId != null
            ? AddressModel(
          id:           apiResult.addressId.toString(),
          name:         result.name,
          fullName:     result.fullName,
          phone:        result.phone,
          addressLine1: result.addressLine1,
          addressLine2: result.addressLine2,
          city:         result.city,
          state:        result.state,
          pinCode:      result.pinCode,
          isDefault:    result.isDefault,
          officeName:   result.officeName,
          block:        result.block,
          floor:        result.floor,
          latitude:     result.latitude,
          longitude:    result.longitude,
          tracking:     result.tracking,
        )
            : result;

        await AddressStorage.add(savedAddress);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Address saved successfully!'),
            backgroundColor: Color(0xFF228B22),
          ));
        }
      } else {
        final apiResult = await _putAddressToServer(result);
        if (!mounted) return;

        if (!apiResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(apiResult.message.isNotEmpty
                ? apiResult.message : 'Failed to update address.'),
            backgroundColor: Colors.red,
          ));
          return;
        }

        await AddressStorage.update(result);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Address updated successfully!'),
            backgroundColor: Color(0xFFFF0080),
          ));
        }
      }
      await _load();
    }
  }

  Future<AddAddressResult> _postAddressToServer(AddressModel address) async {
    final parts     = address.fullName.trim().split(' ');
    final firstname = parts.isNotEmpty ? parts.first : '';
    final lastname  = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final company   = address.name == 'Office' ? (address.officeName ?? '') : address.name;
    final address2parts = <String>[
      if (address.name == 'Office') ...[
        if ((address.block ?? '').isNotEmpty) 'Block: ${address.block}',
        if ((address.floor ?? '').isNotEmpty) 'Floor: ${address.floor}',
      ],
      if (address.addressLine2.isNotEmpty) address.addressLine2,
    ];

    return AddAddressApi.addAddress(
      token: widget.token, customerId: widget.customerId,
      firstname: firstname, lastname: lastname,
      contact: address.phone, company: company,
      addressLine1: address.addressLine1,
      addressLine2: address2parts.join(', '),
      city: address.city, postcode: address.pinCode,
      countryId: 99, zoneId: 0,
      isDefault: address.isDefault,
      tracking: (address.latitude != null && address.longitude != null)
          ? 'https://www.google.com/maps/dir/?api=1&destination=${address.latitude},${address.longitude}&travelmode=driving'
          : 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent([
        address.addressLine1,
        address.addressLine2,
        address.city,
        address.pinCode,
        'India',
      ].where((s) => s.isNotEmpty).join(', '))}&travelmode=driving',
    );
  }

  Future<EditAddressResult> _putAddressToServer(
      AddressModel address, {
        bool forceDefault = false,
      }) async {
    final parts     = address.fullName.trim().split(' ');
    final firstname = parts.isNotEmpty ? parts.first : '';
    final lastname  = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final company   = address.name == 'Office' ? (address.officeName ?? '') : address.name;
    final address2parts = <String>[
      if (address.name == 'Office') ...[
        if ((address.block ?? '').isNotEmpty) 'Block: ${address.block}',
        if ((address.floor ?? '').isNotEmpty) 'Floor: ${address.floor}',
      ],
      if (address.addressLine2.isNotEmpty) address.addressLine2,
    ];

    return EditAddressApi.editAddress(
      token: widget.token, addressId: address.id,
      firstname: firstname, lastname: lastname,
      contact: address.phone, company: company,
      addressLine1: address.addressLine1,
      addressLine2: address2parts.join(', '),
      city: address.city, postcode: address.pinCode,
      countryId: 99, zoneId: 0,
      isDefault: forceDefault || address.isDefault,
    );
  }

  Future<void> _deleteAddress(AddressModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Address',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Remove "${a.name}" address?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF0080)),
        ),
      );
    }

    final apiResult = await DeleteAddressApi.deleteAddress(
      token:     widget.token,
      addressId: a.id,
    );

    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    if (!apiResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(apiResult.message.isNotEmpty
            ? apiResult.message : 'Failed to delete address.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    await AddressStorage.delete(a.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Address deleted successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.selectMode ? 'Select Delivery Address' : 'Saved Addresses',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF0080)),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          if (_addresses.length < 20)
            TextButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, color: Color(0xFFFF0080), size: 18),
              label: const Text('Add',
                  style: TextStyle(
                      color: Color(0xFFFF0080), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0080)))
          : _addresses.isEmpty
          ? _buildEmpty()
          : _buildList(),
      floatingActionButton: (!_loading && _addresses.length < 20)
          ? FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFFFF0080),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add New Address',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      )
          : null,
    );
  }

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
              color: const Color(0xFFFF0080).withOpacity(0.08),
              shape: BoxShape.circle),
          child: const Icon(Icons.location_off_outlined,
              size: 50, color: Color(0xFFFF0080)),
        ),
        const SizedBox(height: 20),
        const Text('No Saved Addresses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Text('Add your home, office or any\ndelivery address here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
          label: const Text('Add Address',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF0080),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    ),
  );

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (widget.selectMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Choose where to deliver your order',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
        ..._addresses.map((a) => _AddressTile(
          address: a,
          selectMode: widget.selectMode,
          onSelect: () => _selectAddress(a),
          onEdit: () => _openForm(existing: a),
          onDelete: () => _deleteAddress(a),
        )),
      ],
    );
  }
}

// ─── Address Tile ─────────────────────────────────────────────────────────────
class _AddressTile extends StatelessWidget {
  final AddressModel address;
  final bool         selectMode;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressTile({
    required this.address,
    required this.selectMode,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDefault = address.isDefault;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDefault
              ? const Color(0xFFFF0080).withOpacity(0.5)
              : Colors.grey[200]!,
          width: isDefault ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDefault
                ? const Color(0xFFFF0080).withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: isDefault ? 10 : 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0080).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconFor(address.name),
                      color: const Color(0xFFFF0080), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(address.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0080).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('DEFAULT',
                              style: TextStyle(
                                  fontSize: 9, color: Color(0xFFFF0080),
                                  fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(address.fullName,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    if (address.name.toLowerCase() == 'office') ...[
                      if ((address.officeName ?? '').isNotEmpty)
                        _subDetail('🏢 ${address.officeName}'),
                      if ((address.block ?? '').isNotEmpty)
                        _subDetail('Block: ${address.block}'),
                      if ((address.floor ?? '').isNotEmpty)
                        _subDetail('Floor: ${address.floor}'),
                    ],
                  ]),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _ActionBtn(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF1976D2),
                      tooltip: 'Edit',
                      onTap: onEdit),
                  const SizedBox(width: 4),
                  _ActionBtn(
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      tooltip: 'Delete',
                      onTap: onDelete),
                ]),
              ]),
              const SizedBox(height: 10),
              Divider(color: Colors.grey[100], height: 1),
              const SizedBox(height: 10),
              _detailRow(Icons.phone_outlined, address.phone),
              const SizedBox(height: 6),
              _detailRow(Icons.location_on_outlined, address.singleLine),
              if (address.hasGpsPin) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.gps_fixed, size: 14, color: Color(0xFFFF0080)),
                  const SizedBox(width: 6),
                  Text('GPS pinned · exact delivery point saved',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
              ],

              const SizedBox(height: 12),
              if (isDefault && !selectMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0080).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF0080), width: 1.2),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFFFF0080), size: 15),
                        SizedBox(width: 6),
                        Text(
                          'This is your Default Address',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF0080)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!isDefault || selectMode)
                GestureDetector(
                  onTap: onSelect,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: selectMode
                            ? const Color(0xFFFF0080)
                            : const Color(0xFFFF0080).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: selectMode
                            ? null
                            : Border.all(color: const Color(0xFFFF0080), width: 1.2)),
                    child: Center(
                      child: Text(
                        selectMode ? 'Deliver Here' : 'Set as Default',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: selectMode
                                ? Colors.white
                                : const Color(0xFFFF0080)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _subDetail(String text) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
  );

  Widget _detailRow(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: Colors.grey[500]),
      const SizedBox(width: 6),
      Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis)),
    ],
  );

  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('home'))   return Icons.home_outlined;
    if (l.contains('office') || l.contains('work')) return Icons.work_outline;
    return Icons.location_on_outlined;
  }
}

// ─── Small Action Button ──────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   tooltip;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color,
    required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
    ),
  );
}

// ─── Address Form Screen ──────────────────────────────────────────────────────
class _AddressFormScreen extends StatefulWidget {
  final AddressModel? existing;
  final bool          forceDefault;
  final String        token; // ← needed for zone check

  const _AddressFormScreen({
    this.existing,
    this.forceDefault = false,
    required this.token,
  });

  @override
  State<_AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<_AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullName, _phone, _line1, _line2,
      _city, _state, _pin, _officeName, _block, _floor;

  String  _label            = 'Home';
  bool    _isDefault        = false;
  bool    _saving           = false;

  double? _latitude;
  double? _longitude;
  bool    _fetchingLocation = false;

  static const _labels = ['Home', 'Office', 'Other'];
  bool get _isOffice => _label == 'Office';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _fullName   = TextEditingController(text: e?.fullName     ?? '');
    _phone      = TextEditingController(text: e?.phone        ?? '');
    _line1      = TextEditingController(text: e?.addressLine1 ?? '');
    _line2      = TextEditingController(text: e?.addressLine2 ?? '');
    _city       = TextEditingController(text: e?.city         ?? '');
    _state      = TextEditingController(text: e?.state        ?? '');
    _pin        = TextEditingController(text: e?.pinCode      ?? '');
    _officeName = TextEditingController(text: e?.officeName   ?? '');
    _block      = TextEditingController(text: e?.block        ?? '');
    _floor      = TextEditingController(text: e?.floor        ?? '');
    _label      = e?.name      ?? 'Home';
    _isDefault  = e?.isDefault ?? widget.forceDefault;
    _latitude   = e?.latitude;
    _longitude  = e?.longitude;
  }

  @override
  void dispose() {
    for (final c in [_fullName, _phone, _line1, _line2, _city, _state,
      _pin, _officeName, _block, _floor]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Live location logic ───────────────────────────────────────────────────

  Future<void> _fetchLiveLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _showLocationError('Location permission denied. Please enable it in Settings.');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Location services are disabled. Please turn on GPS.');
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude  = position.latitude;
        _longitude = position.longitude;
      });

      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark p = placemarks.first;

        final String subThoroughfare = p.subThoroughfare ?? '';
        final String thoroughfare    = p.thoroughfare    ?? '';
        final String subLocality     = p.subLocality     ?? '';
        final String locality        = p.locality        ?? '';
        final String postalCode      = p.postalCode      ?? '';
        final String adminArea       = p.administrativeArea ?? '';

        final flatParts = <String>[
          if (subThoroughfare.isNotEmpty) subThoroughfare,
          if (thoroughfare.isNotEmpty)    thoroughfare,
        ];

        setState(() {
          if (flatParts.isNotEmpty) _line1.text = flatParts.join(', ');
          if (subLocality.isNotEmpty) _line2.text = subLocality;
          if (locality.isNotEmpty)    _city.text  = locality;
          if (postalCode.isNotEmpty)  _pin.text   = postalCode;
          if (adminArea.isNotEmpty)   _state.text = adminArea;
        });

        _showSnack('Location detected and address filled!', Colors.green);
      }
    } catch (e) {
      _showLocationError('Could not detect location: $e');
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    setState(() => _fetchingLocation = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          TextButton(
            onPressed: () { Navigator.pop(context); Geolocator.openAppSettings(); },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color,
          duration: const Duration(seconds: 3)),
    );
  }

  // ── Zone unavailable popup ────────────────────────────────────────────────
  void _showZoneUnavailableDialog(String pincode) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ──────────────────────────────────────────────────────
              Container(
                width:  80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.location_off_rounded,
                        size: 44, color: Colors.red.withOpacity(0.3)),
                    Positioned(
                      bottom: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.red, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ─────────────────────────────────────────────────────
              const Text(
                'Delivery Unavailable',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 10),

              // ── Pincode chip ──────────────────────────────────────────────
              if (pincode.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pin_drop_outlined,
                          size: 14, color: Colors.red),
                      const SizedBox(width: 5),
                      Text('Pincode: $pincode',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // ── Message ───────────────────────────────────────────────────
              Text(
                'Sorry, we\'re unable to deliver to this address. '
                    'We haven\'t reached your area yet, but we\'re expanding fast!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 24),

              // ── Button ────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC5500),
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
  }

  // ── Save with zone check ──────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final pin = _pin.text.trim();

    // ── Show loading ───────────────────────────────────────────────────────
    setState(() => _saving = true);

    // ── Zone check ─────────────────────────────────────────────────────────
    final zoneResult = await ZoneCheckService.check(
      postcode: pin,
      token:    widget.token,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (zoneResult.hasError) {
      _showSnack('Could not verify delivery zone: ${zoneResult.error}', Colors.orange);

      return;
    }

    if (!zoneResult.available) {
      // ── Zone not serviceable → show popup, stay on form ────────────────
      _showZoneUnavailableDialog(pin);
      return;
    }

    // ── Zone is available → pop with the address ───────────────────────────
    Navigator.pop(
      context,
      AddressModel(
        id:           widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name:         _label,
        fullName:     _fullName.text.trim(),
        phone:        _phone.text.trim(),
        addressLine1: _line1.text.trim(),
        addressLine2: _line2.text.trim(),
        city:         _city.text.trim(),
        state:        _state.text.trim(),
        pinCode:      pin,
        isDefault:    _isDefault,
        officeName:   _isOffice ? _officeName.text.trim() : null,
        block:        _isOffice ? _block.text.trim()      : null,
        floor:        _isOffice ? _floor.text.trim()      : null,
        latitude:     _latitude,
        longitude:    _longitude,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
        title: Text(isEdit ? 'Edit Address' : 'Add New Address',
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.grey[200])),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [

            // ── Address Type ─────────────────────────────────────────────
            _SectionTitle('Address Type'),
            const SizedBox(height: 8),
            Row(
              children: _labels.map((l) {
                final sel = _label == l;
                return GestureDetector(
                  onTap: () => setState(() => _label = l),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFFF0080) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? const Color(0xFFFF0080) : Colors.grey[300]!),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_iconFor(l), size: 16,
                          color: sel ? Colors.white : Colors.grey[600]),
                      const SizedBox(width: 5),
                      Text(l, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : Colors.grey[700])),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Contact Details ──────────────────────────────────────────
            _SectionTitle('Contact Details'),
            const SizedBox(height: 10),
            _field(
                controller: _fullName,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            _field(
                controller: _phone,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Required';
                  if (v.trim().length != 10) return 'Enter 10-digit number';
                  return null;
                }),
            const SizedBox(height: 16),

            // ── Live Location Card ────────────────────────────────────────
            _buildLiveLocationCard(),
            const SizedBox(height: 20),

            // ── Office / Home / Other Address Details ─────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _isOffice
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle('Office Details'),
                const SizedBox(height: 10),
                _field(
                    controller: _officeName,
                    label: 'Office / Company Name',
                    icon: Icons.business_outlined),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(
                      controller: _block,
                      label: 'Block / Tower',
                      icon: Icons.domain_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(
                      controller: _floor,
                      label: 'Floor',
                      icon: Icons.layers_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
                ]),
                const SizedBox(height: 12),
                _field(
                    controller: _line1,
                    label: 'House No., Building, Street',
                    icon: Icons.home_outlined,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                _field(
                    controller: _line2,
                    label: 'Area, Colony (Optional)',
                    icon: Icons.map_outlined),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(
                      controller: _city,
                      label: 'City',
                      icon: Icons.location_city_outlined,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(
                      controller: _state,
                      label: 'State',
                      icon: Icons.flag_outlined,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null)),
                ]),
                const SizedBox(height: 12),
                _field(
                    controller: _pin,
                    label: 'PIN Code',
                    icon: Icons.pin_drop_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    validator: (v) {
                      if (v!.trim().isEmpty) return 'Required';
                      if (v.trim().length != 6) return 'Enter 6-digit PIN';
                      return null;
                    }),
                const SizedBox(height: 20),
              ])
                  : const SizedBox.shrink(),
            ),
            if (!_isOffice) ...[
              _SectionTitle('Address Details'),
              const SizedBox(height: 10),
              _field(
                  controller: _line1,
                  label: 'House No., Building, Street',
                  icon: Icons.home_outlined,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              _field(
                  controller: _line2,
                  label: 'Area, Colony (Optional)',
                  icon: Icons.map_outlined),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(
                    controller: _city,
                    label: 'City',
                    icon: Icons.location_city_outlined,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null)),
                const SizedBox(width: 12),
                Expanded(child: _field(
                    controller: _state,
                    label: 'State',
                    icon: Icons.flag_outlined,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null)),
              ]),
              const SizedBox(height: 12),
              _field(
                  controller: _pin,
                  label: 'PIN Code',
                  icon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Required';
                    if (v.trim().length != 6) return 'Enter 6-digit PIN';
                    return null;
                  }),
              const SizedBox(height: 20),
            ],

            // ── Default toggle ────────────────────────────────────────────
            if (widget.forceDefault || isEdit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFFFF0080),
                  title: const Text('Set as default address',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Use this for all deliveries by default',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
              ),
            const SizedBox(height: 28),

            // ── Save button ───────────────────────────────────────────────
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0080),
                disabledBackgroundColor: const Color(0xFFFF0080).withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                  height: 20,
                  width:  20,
                  child:  CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Update Address' : 'Save Address',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live Location Card ─────────────────────────────────────────────────────
  Widget _buildLiveLocationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        border: Border.all(color: const Color(0xFFFFB300), width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.my_location_rounded,
                color: Color(0xFFFF0080), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Use live location',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text('Auto-fill address from your GPS',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
          ),
          if (_latitude != null)
            GestureDetector(
              onTap: () => setState(() { _latitude = null; _longitude = null; }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.green),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _fetchingLocation ? null : _fetchLiveLocation,
            icon: _fetchingLocation
                ? const SizedBox(width: 15, height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.gps_fixed, size: 16),
            label: Text(
              _fetchingLocation
                  ? 'Detecting...'
                  : _latitude != null
                  ? 'Update location'
                  : 'Detect my location',
              style: const TextStyle(fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0080),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        if (_latitude != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Pinned · ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11, color: Colors.green,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController   controller,
    required String                  label,
    required IconData                icon,
    TextInputType?                   keyboardType,
    List<TextInputFormatter>?        inputFormatters,
    int?                             maxLength,
    String? Function(String?)?       validator,
  }) {
    return TextFormField(
      controller:      controller,
      keyboardType:    keyboardType,
      inputFormatters: inputFormatters,
      maxLength:       maxLength,
      validator:       validator,
      style:           const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText:    label,
        labelStyle:   TextStyle(fontSize: 13, color: Colors.grey[600]),
        prefixIcon:   Icon(icon, size: 18, color: Colors.grey[500]),
        filled:       true,
        fillColor:    Colors.white,
        counterText:  '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFF0080), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }

  IconData _iconFor(String label) {
    switch (label) {
      case 'Home':   return Icons.home_outlined;
      case 'Office': return Icons.work_outline;
      default:       return Icons.location_on_outlined;
    }
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
          color: Colors.grey[700]));
}