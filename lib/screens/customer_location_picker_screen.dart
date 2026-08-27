import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class CustomerLocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const CustomerLocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<CustomerLocationPickerScreen> createState() =>
      _CustomerLocationPickerScreenState();
}

class _NominatimResult {
  final String displayName;
  final double lat;
  final double lon;

  _NominatimResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });
}

class _CustomerLocationPickerScreenState
    extends State<CustomerLocationPickerScreen> {
  final MapController _mapController = MapController();

  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  late LatLng _pickedLatLng;

  bool _loadingLocation = false;
  bool _searching = false;

  List<_NominatimResult> _searchResults = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    _pickedLatLng = LatLng(
      widget.initialLat ?? 16.9891,
      widget.initialLng ?? 82.2475,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 600),
          () => _runSearch(query.trim()),
    );
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;

    setState(() {
      _searching = true;
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeQueryComponent(query)}'
            '&format=json'
            '&addressdetails=1'
            '&limit=6'
            '&countrycodes=in',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'MtlGroceriesApp/1.0',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final results = data.map<_NominatimResult>((item) {
          return _NominatimResult(
            displayName: item['display_name'] ?? '',
            lat: double.parse(item['lat'].toString()),
            lon: double.parse(item['lon'].toString()),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _searchResults = results;
          });
        }
      }
    } catch (e) {
      debugPrint('Nominatim search error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  void _selectSearchResult(_NominatimResult result) {
    final newLocation = LatLng(
      result.lat,
      result.lon,
    );

    setState(() {
      _pickedLatLng = newLocation;
      _searchResults = [];
      _searchController.text = result.displayName;
    });

    _searchFocusNode.unfocus();

    _mapController.move(
      newLocation,
      16,
    );
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Future<void> _useCurrentLocation() async {
    if (_loadingLocation) return;

    setState(() {
      _loadingLocation = true;
    });

    try {
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location services are disabled. Please enable GPS.',
        );
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission denied.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied. '
              'Please enable it from Settings.',
        );
      }

      // IMPORTANT:
      // For geolocator ^11.0.0 use desiredAccuracy.
      // Do NOT use locationSettings here.
      final Position position =
      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _pickedLatLng = newLocation;
        _searchController.clear();
        _searchResults = [];
      });

      _mapController.move(
        newLocation,
        17,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst(
                'Exception: ',
                '',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // MAP TAP
  // ============================================================

  void _onMapTap(
      TapPosition tapPosition,
      LatLng latLng,
      ) {
    setState(() {
      _pickedLatLng = latLng;
      _searchResults = [];
    });

    _searchFocusNode.unfocus();
  }

  // ============================================================
  // CONFIRM
  // ============================================================

  void _confirm() {
    Navigator.pop(
      context,
      {
        'latitude': _pickedLatLng.latitude,
        'longitude': _pickedLatLng.longitude,
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Delivery Location',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _confirm,
            icon: const Icon(Icons.check),
            tooltip: 'Confirm',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ======================================================
          // MAP
          // ======================================================

          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedLatLng,
              initialZoom: 15,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                // Change this to your real Android package name.
                userAgentPackageName:
                'com.yourcompany.mtl_groceriesapp',
              ),

              MarkerLayer(
                markers: [
                  Marker(
                    point: _pickedLatLng,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ======================================================
          // SEARCH
          // ======================================================

          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText:
                      'Search area, street, landmark...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                      ),
                      suffixIcon: _searching
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                          : _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                        ),
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 10,
                      ),
                    ),
                  ),
                ),

                // =================================================
                // SEARCH RESULTS
                // =================================================

                if (_searchResults.isNotEmpty)
                  Container(
                    margin:
                    const EdgeInsets.only(top: 5),
                    constraints:
                    const BoxConstraints(
                      maxHeight: 260,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount:
                      _searchResults.length,
                      separatorBuilder:
                          (_, __) =>
                      const Divider(
                        height: 1,
                      ),
                      itemBuilder:
                          (context, index) {
                        final result =
                        _searchResults[index];

                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Colors.red,
                          ),
                          title: Text(
                            result.displayName,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                            ),
                          ),
                          onTap: () =>
                              _selectSearchResult(
                                result,
                              ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ======================================================
          // CURRENT LOCATION
          // ======================================================

          Positioned(
            right: 16,
            bottom: 105,
            child: FloatingActionButton(
              heroTag: 'customerCurrentLocation',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 4,
              onPressed:
              _loadingLocation
                  ? null
                  : _useCurrentLocation,
              child: _loadingLocation
                  ? const SizedBox(
                width: 22,
                height: 22,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.my_location,
              ),
            ),
          ),

          // ======================================================
          // CONFIRM BAR
          // ======================================================

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
              const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style:
                    ElevatedButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          10,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Confirm This Location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                        FontWeight.bold,
                      ),
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
}