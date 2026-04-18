import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtl_groceriesapp/services/session_manager.dart';

class AddressModel {
  final String  id;
  final String  name;
  final String  fullName;
  final String  phone;
  final String  addressLine1;
  final String  addressLine2;
  final String  city;
  final String  state;
  final String  pinCode;
  final bool    isDefault;
  final String? officeName;
  final String? block;
  final String? floor;
  final double? latitude;
  final double? longitude;
  final String? tracking;

  const AddressModel({
    required this.id,
    required this.name,
    required this.fullName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.state,
    required this.pinCode,
    this.isDefault  = false,
    this.officeName,
    this.block,
    this.floor,
    this.latitude,
    this.longitude,
    this.tracking,
  });

  bool get hasGpsPin => latitude != null && longitude != null;

  String get singleLine {
    final parts = [
      addressLine1,
      if (addressLine2.isNotEmpty) addressLine2,
      city,
      if (state.isNotEmpty) state,
      pinCode,
    ];
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
    'id':           id,
    'name':         name,
    'fullName':     fullName,
    'phone':        phone,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'city':         city,
    'state':        state,
    'pinCode':      pinCode,
    'isDefault':    isDefault,
    if (officeName != null) 'officeName': officeName,
    if (block      != null) 'block':      block,
    if (floor      != null) 'floor':      floor,
    if (latitude   != null) 'latitude':   latitude,
    if (longitude  != null) 'longitude':  longitude,
    if (tracking   != null) 'tracking':   tracking,
  };

  factory AddressModel.fromJson(Map<String, dynamic> json) => AddressModel(
    id:           json['id']           as String,
    name:         json['name']         as String,
    fullName:     json['fullName']     as String,
    phone:        json['phone']        as String,
    addressLine1: json['addressLine1'] as String,
    addressLine2: json['addressLine2'] as String? ?? '',
    city:         json['city']         as String,
    state:        json['state']        as String,
    pinCode:      json['pinCode']      as String,
    isDefault:    json['isDefault']    as bool? ?? false,
    officeName:   json['officeName']   as String?,
    block:        json['block']        as String?,
    floor:        json['floor']        as String?,
    latitude:     (json['latitude']  as num?)?.toDouble(),
    longitude:    (json['longitude'] as num?)?.toDouble(),
    tracking:     json['tracking']   as String?,
  );

  AddressModel copyWith({
    String?  id,
    String?  name,
    String?  fullName,
    String?  phone,
    String?  addressLine1,
    String?  addressLine2,
    String?  city,
    String?  state,
    String?  pinCode,
    bool?    isDefault,
    String?  officeName,
    String?  block,
    String?  floor,
    double?  latitude,
    double?  longitude,
    String?  tracking,
  }) => AddressModel(
    id:           id           ?? this.id,
    name:         name         ?? this.name,
    fullName:     fullName     ?? this.fullName,
    phone:        phone        ?? this.phone,
    addressLine1: addressLine1 ?? this.addressLine1,
    addressLine2: addressLine2 ?? this.addressLine2,
    city:         city         ?? this.city,
    state:        state        ?? this.state,
    pinCode:      pinCode      ?? this.pinCode,
    isDefault:    isDefault    ?? this.isDefault,
    officeName:   officeName   ?? this.officeName,
    block:        block        ?? this.block,
    floor:        floor        ?? this.floor,
    latitude:     latitude     ?? this.latitude,
    longitude:    longitude    ?? this.longitude,
    tracking:     tracking     ?? this.tracking,
  );
}

class AddressStorage {
  static Future<String> _key() async => SessionManager.addressKey();

  static Future<List<AddressModel>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(await _key());
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<AddressModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        await _key(), jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> add(AddressModel address) async {
    final list = await load();
    final idx = list.indexWhere((e) => e.id == address.id);
    if (idx != -1) {
      list[idx] = address;
    } else {
      list.add(address);
    }
    await _save(list);
  }

  static Future<void> update(AddressModel address) async {
    final list = await load();
    final idx  = list.indexWhere((e) => e.id == address.id);
    if (idx != -1) {
      list[idx] = address;
    } else {
      list.add(address);
    }
    await _save(list);
  }

  static Future<void> delete(String id) async {
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await _save(list);
  }

  static Future<void> setDefault(String id) async {
    final list    = await load();
    // Use copyWith so lat/lng and all other fields are preserved automatically
    final updated = list.map((e) => e.copyWith(isDefault: e.id == id)).toList();
    await _save(updated);
  }

  // Replace entire local list with server data (used after getAddress API)
  static Future<void> replaceAll(List<AddressModel> list) async {
    await _save(list);
  }

  // Get the default address (first one marked isDefault, else first in list)
  static Future<AddressModel?> getDefault() async {
    final list = await load();
    if (list.isEmpty) return null;
    try {
      return list.firstWhere((e) => e.isDefault);
    } catch (_) {
      return list.first;
    }
  }
}