import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config_service.dart';

class RewardResult {
  final bool   success;
  final int    totalPoints;
  final String error;

  const RewardResult._({
    required this.success,
    this.totalPoints = 0,
    this.error       = '',
  });

  factory RewardResult.ok(int points) =>
      RewardResult._(success: true, totalPoints: points);

  factory RewardResult.fail(String message) =>
      RewardResult._(success: false, error: message);

  bool get hasError => error.isNotEmpty;
}

class GetRewardService {
  static Future<RewardResult> getReward({required String token}) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.indexPhp}'
            '?route=groceries/categories.getReward'
            '&token=$token',
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return RewardResult.fail('Server error (${response.statusCode})');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['status'] != 'success') {
        return RewardResult.fail(
            body['message']?.toString() ?? 'Unknown error');
      }

      final points = int.tryParse(
        body['total_points']?.toString() ?? '0',
      ) ??
          0;

      return RewardResult.ok(points);
    } catch (e) {
      return RewardResult.fail(e.toString());
    }
  }
}