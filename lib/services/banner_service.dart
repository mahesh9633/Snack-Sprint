import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config_service.dart';

class ApiBanner {
  final String bannerId;
  final String title;
  final String image;
  final String link;        // kept for backward-compat / fallback only
  final String categoryId;
  final String categoryName;

  const ApiBanner({
    required this.bannerId,
    required this.title,
    required this.image,
    required this.link,
    required this.categoryId,
    required this.categoryName,
  });

  String get imageUrl {
    if (image.isEmpty) return '';
    if (image.startsWith('http')) return image;
    return '${ApiConfig.imageBase}$image';
  }

  /// True when this banner should navigate to a category screen
  /// instead of (or in addition to) opening a link.
  bool get hasCategory => categoryId.isNotEmpty && categoryId != '0';

  factory ApiBanner.fromJson(Map<String, dynamic> j) {
    final String rawLink = j['link']?.toString() ?? '';

    // 🔑 getRunningBanners puts the category id inside "link" itself
    // (no separate "category_id" key in that response) — it's always
    // a bare numeric id like "172", never a real http(s) URL.
    // Other endpoints (getActiveBanners) alias the same column as
    // "category_id" directly, so check that key first.
    final bool linkIsNumericId =
        rawLink.isNotEmpty && int.tryParse(rawLink) != null;

    final String resolvedCategoryId =
    (j['category_id']?.toString().isNotEmpty == true)
        ? j['category_id'].toString()
        : (linkIsNumericId ? rawLink : '');

    return ApiBanner(
      bannerId: j['banner_id']?.toString() ??
          j['id']?.toString()              ?? '',
      title:    j['title']?.toString()     ??
          j['name']?.toString()            ?? '',
      image:    j['image']?.toString()     ?? '',
      // only keep as a launchable link if it WASN'T a numeric category id
      link:     linkIsNumericId ? '' : rawLink,
      categoryId: resolvedCategoryId,
      categoryName: j['category_name']?.toString() ?? '',
    );
  }
}

Future<List<ApiBanner>> getRunningBanners({String? token}) async {
  try {
    final url = ApiConfig.route(
      'groceries/categories.getRunningBanners',
      token: token,
    );

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      print('🔵 RAW BANNER RESPONSE: ${response.body}');
      List<dynamic> raw = [];

      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map) {
        final status = decoded['status']?.toString() ?? '';
        if (status == 'success' || status == '1' || status == 'true') {
          raw = decoded['data'] as List? ?? [];
        } else {
          raw = decoded['banners'] as List? ??
              decoded['data']      as List? ??
              decoded['items']     as List? ??
              decoded['results']   as List? ?? [];
        }
      }

      // return raw
      //     .map((b) => ApiBanner.fromJson(b as Map<String, dynamic>))
      //     .where((b) => b.image.isNotEmpty)
      //     .toList();
      final banners = raw
          .map((b) => ApiBanner.fromJson(b as Map<String, dynamic>))
          .where((b) => b.image.isNotEmpty)
          .toList();

      for (final b in banners) {
        return banners;
      }}
  } catch (e) {
    // ignore
  }
  return [];
}
Future<List<ApiBanner>> getBottomBanners({String? token}) async {
  try {
    final url = ApiConfig.route(
      'groceries/categories.getBottomBanners',
      token: token,
    );

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      List<dynamic> raw = [];

      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map) {
        final status = decoded['status']?.toString() ?? '';
        if (status == 'success' || status == '1' || status == 'true') {
          raw = decoded['data'] as List? ?? [];
        } else {
          raw = decoded['banners'] as List? ??
              decoded['data']      as List? ??
              decoded['items']     as List? ??
              decoded['results']   as List? ?? [];
        }
      }

      return raw
          .map((b) => ApiBanner.fromJson(b as Map<String, dynamic>))
          .where((b) => b.image.isNotEmpty)
          .toList();
    }
  } catch (e) {
    // ignore
  }
  return [];
}