import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config_service.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class TrackOrderStep {
  final String trackStatusId;
  final String name;
  final bool isCompleted; // status == "1"

  const TrackOrderStep({
    required this.trackStatusId,
    required this.name,
    required this.isCompleted,
  });

  factory TrackOrderStep.fromJson(Map<String, dynamic> json) {
    return TrackOrderStep(
      trackStatusId: json['track_status_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isCompleted: json['status']?.toString() == '1',
    );
  }
}

class TrackOrderResult {
  final bool success;
  final List<TrackOrderStep> steps;
  final String message;

  const TrackOrderResult({
    required this.success,
    required this.steps,
    this.message = '',
  });
}

// ── Service ──────────────────────────────────────────────────────────────────

class TrackOrderService {
  static Future<TrackOrderResult> getTrackOrder({
    required String token,
    required String orderId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.route('groceries/categories..getTrackOrder', token: token)}'
            '&order_id=$orderId',
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'success') {
          final rawList = data['data'] as List<dynamic>? ?? [];
          final steps = rawList
              .map((e) => TrackOrderStep.fromJson(e as Map<String, dynamic>))
              .toList();
          return TrackOrderResult(success: true, steps: steps);
        } else {
          return TrackOrderResult(
            success: false,
            steps: [],
            message: data['message']?.toString() ?? 'Unknown error',
          );
        }
      } else {
        return TrackOrderResult(
          success: false,
          steps: [],
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      return TrackOrderResult(
        success: false,
        steps: [],
        message: e.toString(),
      );
    }
  }
}