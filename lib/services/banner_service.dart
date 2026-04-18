import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config_service.dart';

class ApiBanner {
  final String bannerId;
  final String title;
  final String image;
  final String link;

  const ApiBanner({
    required this.bannerId,
    required this.title,
    required this.image,
    required this.link,
  });

  String get imageUrl {
    if (image.isEmpty) return '';
    if (image.startsWith('http')) return image;
    return '${ApiConfig.imageBase}$image';
  }

  factory ApiBanner.fromJson(Map<String, dynamic> j) => ApiBanner(
    bannerId: j['banner_id']?.toString() ??
        j['id']?.toString()              ?? '',
    title:    j['title']?.toString()     ??
        j['name']?.toString()            ?? '',
    image:    j['image']?.toString()     ?? '',
    link:     j['link']?.toString()      ?? '',
  );
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