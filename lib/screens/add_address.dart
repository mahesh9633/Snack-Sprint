import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:mtl_groceriesapp/screens/payment_method.dart';

import '../config/app_color.dart';
import '../model/address_model.dart';
import '../services/add_address_service.dart';
import '../services/pincode_zone_check_service.dart';

class AddAddressScreen extends StatefulWidget {
  final String token;
  final String customerId;

  const AddAddressScreen({
    super.key,
    required this.token,
    required this.customerId,
  });

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey              = GlobalKey<FormState>();
  final _fullNameController   = TextEditingController();
  final _mobileController     = TextEditingController();
  final _flatHouseController  = TextEditingController();
  final _areaStreetController = TextEditingController();
  final _landmarkController   = TextEditingController();
  final _pincodeController    = TextEditingController();
  final _townCityController   = TextEditingController();

  String  _addressType      = 'Home';
  double? _latitude;
  double? _longitude;
  bool    _fetchingLocation = false;
  String  _selectedState    = 'Select';
  bool    _saving           = false;

  static const List<String> _states = [
    'Select',
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
    'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh',
    'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra',
    'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Delhi',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _flatHouseController.dispose();
    _areaStreetController.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    _townCityController.dispose();
    super.dispose();
  }

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
          if (flatParts.isNotEmpty)        _flatHouseController.text  = flatParts.join(', ');
          if (subLocality.isNotEmpty)      _areaStreetController.text = subLocality;
          if (locality.isNotEmpty)         _townCityController.text   = locality;
          if (postalCode.isNotEmpty)       _pincodeController.text    = postalCode;
          if (_states.contains(adminArea)) _selectedState             = adminArea;
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final zoneResult = await ZoneCheckService.check(
        postcode: _pincodeController.text.trim(),
        token:    widget.token,
      );

      if (!mounted) return;

      if (!zoneResult.available) {
        setState(() => _saving = false);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.location_off_rounded,
                    color: AppColors.warning, size: 26),
                SizedBox(width: 10),
                Text(
                  'Delivery Unavailable',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              'We are unable to deliver to your address.\n\n'
                  'We don\'t currently serve the pincode you entered. '
                  'Please try a different delivery address.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.warning),
                child: const Text('OK',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      setState(() => _saving = false);
      _showSnack('Could not verify pincode: $e', Colors.red);
      return;
    }

    try {
      final parts     = _fullNameController.text.trim().split(' ');
      final firstname = parts.isNotEmpty ? parts.first : '';
      final lastname  = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final address2parts = <String>[
        if (_areaStreetController.text.trim().isNotEmpty)
          _areaStreetController.text.trim(),
        if (_landmarkController.text.trim().isNotEmpty)
          'Landmark: ${_landmarkController.text.trim()}',
      ];

      final String mapsLink = _latitude != null
          ? 'https://www.google.com/maps/dir/?api=1&destination=$_latitude,$_longitude&travelmode=driving'
          : 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent([
        _flatHouseController.text.trim(),
        _areaStreetController.text.trim(),
        _townCityController.text.trim(),
        _pincodeController.text.trim(),
        'India',
      ].where((s) => s.isNotEmpty).join(', '))}&travelmode=driving';

      final result = await AddAddressApi.addAddress(
        token:        widget.token,
        customerId:   widget.customerId,
        firstname:    firstname,
        lastname:     lastname,
        contact:      _mobileController.text.trim(),
        company:      _addressType,
        addressLine1: _flatHouseController.text.trim(),
        addressLine2: address2parts.join(', '),
        city:         _townCityController.text.trim(),
        postcode:     _pincodeController.text.trim(),
        countryId:    99,
        zoneId:       0,
        tracking:     mapsLink,
      );

      if (!mounted) return;

      if (result.success) {
        _showSnack('Address saved successfully!', Colors.green);

        final newAddress = AddressModel(
          id:           '',
          name:         _addressType,
          fullName:     _fullNameController.text.trim(),
          phone:        _mobileController.text.trim(),
          addressLine1: _flatHouseController.text.trim(),
          addressLine2: _areaStreetController.text.trim(),
          city:         _townCityController.text.trim(),
          state:        _selectedState,
          pinCode:      _pincodeController.text.trim(),
          isDefault:    true,
          latitude:     _latitude,
          longitude:    _longitude,
          tracking:     mapsLink,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PaymentMethodScreen(selectedAddress: newAddress),
          ),
        );
      } else {
        _showSnack(
          result.message.isNotEmpty
              ? result.message
              : 'Failed to save address. Please try again.',
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Network error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Address',
          style: TextStyle(
            color: AppColors.appBarText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                  color: AppColors.appBarText,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _requiredLabel('Save address as'),
                    const SizedBox(height: 10),
                    Row(children: [
                      _addressTypeChip(
                          label: 'Home', icon: Icons.home_rounded),
                      const SizedBox(width: 8),
                      _addressTypeChip(
                          label: 'Work', icon: Icons.work_rounded),
                      const SizedBox(width: 8),
                      _addressTypeChip(
                          label: 'Other',
                          icon: Icons.location_on_rounded),
                    ]),
                    const SizedBox(height: 18),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 14),

                    _requiredLabel('Full name'),
                    const SizedBox(height: 6),
                    _textField(
                      controller: _fullNameController,
                      hint:       'Enter full name',
                      validator:  (v) => v!.trim().isEmpty
                          ? 'Please enter full name'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    _requiredLabel('Mobile number'),
                    const SizedBox(height: 6),
                    _textField(
                      controller:      _mobileController,
                      hint:            '10-digit mobile number',
                      keyboardType:    TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      maxLength: 10,
                      validator: (v) {
                        if (v!.trim().isEmpty)
                          return 'Please enter mobile number';
                        if (v.trim().length != 10)
                          return 'Enter valid 10-digit number';
                        return null;
                      },
                    ),
                    Text(
                      'May be used to assist delivery',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.appBarText),
                    ),
                    const SizedBox(height: 14),

                    _buildLiveLocationCard(),
                    const SizedBox(height: 18),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 14),

                    _requiredLabel(
                        'Flat, House no., Building, Company, Apartment'),
                    const SizedBox(height: 6),
                    _textField(
                      controller: _flatHouseController,
                      validator:  (v) => v!.trim().isEmpty
                          ? 'Please enter this field'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    _requiredLabel('Area, Street, Sector, Village'),
                    const SizedBox(height: 6),
                    _textField(
                      controller: _areaStreetController,
                      validator:  (v) => v!.trim().isEmpty
                          ? 'Please enter this field'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _requiredLabel('Pincode'),
                            const SizedBox(height: 6),
                            _textField(
                              controller:      _pincodeController,
                              hint:            '6-digit',
                              keyboardType:    TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              maxLength: 6,
                              validator: (v) {
                                if (v!.trim().isEmpty) return 'Required';
                                if (v.trim().length != 6)
                                  return 'Invalid PIN';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _requiredLabel('Town / City'),
                            const SizedBox(height: 6),
                            _textField(
                              controller: _townCityController,
                              validator:  (v) => v!.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    _requiredLabel('State'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedState,
                      decoration: InputDecoration(
                        filled:    true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: _states
                          .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedState = v!),
                      validator: (v) => (v == null || v == 'Select')
                          ? 'Please select a state'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    if (_latitude != null && _longitude != null)
                      _buildCoordinatesBadge(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Bottom button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonPrimary,
                    foregroundColor: AppColors.buttonPrimaryText,
                    padding:
                    const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                    height: 20,
                    width:  20,
                    child:  CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.buttonPrimaryText,
                    ),
                  )
                      : const Text(
                    'Use this address',
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // Step 1: name + phone filled
    final step1Done = _fullNameController.text.trim().isNotEmpty &&
        _mobileController.text.trim().length == 10;

    // Step 2: live location used OR flat+area filled manually
    final step2Done = (_latitude != null && _longitude != null) ||
        (_flatHouseController.text.trim().isNotEmpty &&
            _areaStreetController.text.trim().isNotEmpty);

    // Step 3: pincode + city + state filled
    final step3Done = _pincodeController.text.trim().length == 6 &&
        _townCityController.text.trim().isNotEmpty &&
        _selectedState != 'Select';

    final steps = [step1Done, step2Done, step3Done];

    // Label based on progress
    String stepLabel = 'Step 1 of 3 — Personal details';
    if (step1Done && !step2Done) stepLabel = 'Step 2 of 3 — Address details';
    if (step1Done && step2Done && !step3Done) stepLabel = 'Step 3 of 3 — Location details';
    if (step1Done && step2Done && step3Done) stepLabel = 'All steps completed ✓';

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter a new delivery address',
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.bold,
              color:      Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            stepLabel,
            style: const TextStyle(
                fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: steps[i]
                        ? AppColors.buttonPrimary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _addressTypeChip(
      {required String label, required IconData icon}) {
    final selected = _addressType == label;
    return GestureDetector(
      onTap: () => setState(() => _addressType = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.buttonPrimary : AppColors.white,
          border: Border.all(
            color: selected
                ? AppColors.buttonPrimary
                : AppColors.border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: selected
              ? [
            BoxShadow(
              color:      AppColors.buttonPrimary.withOpacity(0.3),
              blurRadius: 6,
              offset:     const Offset(0, 2),
            )
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size:  14,
              color: selected
                  ? AppColors.buttonPrimaryText
                  : AppColors.appBarText,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize:   12,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: selected
                    ? AppColors.buttonPrimaryText
                    : AppColors.appBarText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveLocationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:  AppColors.white,
        border: Border.all(color: AppColors.buttonPrimary, width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color:  AppColors.buttonPrimary.withOpacity(0.1),
                  shape:  BoxShape.circle,
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.buttonPrimary,
                  size:  18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Use live location',
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.bold,
                        color:      AppColors.buttonPrimary,
                      ),
                    ),
                    Text(
                      "We'll deliver to your exact GPS point",
                      style: TextStyle(
                          fontSize: 11,
                          color:    AppColors.appBarText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
              _fetchingLocation ? null : _fetchLiveLocation,
              icon: _fetchingLocation
                  ? const SizedBox(
                width:  14,
                height: 14,
                child:  CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.buttonPrimaryText,
                ),
              )
                  : const Icon(Icons.gps_fixed, size: 16),
              label: Text(
                _fetchingLocation
                    ? 'Detecting location…'
                    : _latitude != null
                    ? 'Update live location'
                    : 'Detect my location',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                foregroundColor: AppColors.buttonPrimaryText,
                elevation:       0,
                padding:
                const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (_latitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 14),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'GPS pinned · ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize:   11,
                        color:      Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _latitude  = null;
                      _longitude = null;
                    }),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoordinatesBadge() {
    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color:        Colors.green.shade50,
        border:       Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.location_pin,
              color: Colors.green.shade700, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Exact delivery point saved\nLat: ${_latitude!.toStringAsFixed(6)}  |  Lng: ${_longitude!.toStringAsFixed(6)}',
              style: TextStyle(
                fontSize: 11,
                color:    Colors.green.shade800,
                height:   1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requiredLabel(String text) => RichText(
    text: TextSpan(
      children: [
        TextSpan(
          text:  text,
          style: const TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.bold,
            color:      AppColors.appBarText,
          ),
        ),
        const TextSpan(
          text:  ' *',
          style: TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.bold,
            color:      Colors.red,
          ),
        ),
      ],
    ),
  );

  Widget _textField({
    required TextEditingController    controller,
    String?                           hint,
    TextInputType?                    keyboardType,
    List<TextInputFormatter>?         inputFormatters,
    int?                              maxLength,
    String? Function(String?)?        validator,
  }) {
    return TextFormField(
      controller:      controller,
      keyboardType:    keyboardType,
      inputFormatters: inputFormatters,
      maxLength:       maxLength,
      validator:       validator,
      onChanged:       (_) => setState(() {}),
      style: const TextStyle(
          fontSize: 13, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(
            fontSize: 13, color: AppColors.appBarText),
        counterText: '',
        filled:      true,
        fillColor:   AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
              color: AppColors.buttonPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 11),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear,
              size: 16, color: Colors.grey),
          onPressed: () {
            controller.clear();
            setState(() {});
          },
        )
            : null,
      ),
    );
  }
}