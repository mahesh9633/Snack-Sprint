import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config_service.dart';
class BannerItem {
  final String bannerId;
  final String name;
  final String title;
  final String image;
  final String link;
  final String categoryId;
  final String categoryName;
  final int    sortOrder;

  const BannerItem({
    required this.bannerId,
    required this.name,
    required this.title,
    required this.image,
    required this.link,
    required this.categoryId,
    required this.categoryName,
    required this.sortOrder,
  });

  String get imageUrl {
    if (image.isEmpty) return '';
    return image.startsWith('http')
        ? image
        : '${ApiConfig.imageBase}$image';
  }

  /// True when this banner should navigate to a category screen in-app.
  // bool get hasCategory => categoryId.isNotEmpty && categoryId != '0';
  bool get hasCategory =>
      categoryId.isNotEmpty && int.tryParse(categoryId) != null && categoryId != '0';

  /// Builds the full product/category link from the relative route
  /// — only used as a fallback when there's no category_id at all.
  String get fullLink {
    if (link.isEmpty) return '';
    // Already a full URL — use as-is
    if (link.startsWith('http://') || link.startsWith('https://')) return link;
    // Looks like a domain without scheme (e.g. www.myteknoland.com)
    if (link.startsWith('www.')) return 'https://$link';
    // Relative route like: index.php?route=product/product&product_id=40
    final clean = link.startsWith('/') ? link.substring(1) : link;
    return '${ApiConfig.baseUrl}/$clean';
  }

  factory BannerItem.fromJson(Map<String, dynamic> j) {
    return BannerItem(
      bannerId:     j['banner_id']?.toString()    ?? '',
      name:         j['name']?.toString()         ?? '',
      title:        j['title']?.toString()        ?? '',
      image:        j['image']?.toString()        ?? '',
      link:         j['link']?.toString()          ?? '',
      categoryId:   j['category_id']?.toString()   ?? '',
      categoryName: j['category_name']?.toString() ?? '',
      sortOrder:    int.tryParse(j['sort_order']?.toString() ?? '0') ?? 0,
    );
  }
}

Future<List<BannerItem>> getBanners({String? token}) async {
  try {
    final url = Uri.parse(
      ApiConfig.route('groceries/categories..getBanners', token: token),
    );
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    if (decoded['status'] != 'success') return [];
    final list = decoded['data'] as List? ?? [];
    final banners = list
        .map((e) => BannerItem.fromJson(e as Map<String, dynamic>))
        .toList();
    banners.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return banners;
  } catch (_) {
    return [];
  }
}