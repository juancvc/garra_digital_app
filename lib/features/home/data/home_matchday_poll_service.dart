import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class HomeMatchdayPollOption {
  const HomeMatchdayPollOption({
    required this.id, required this.label, required this.voteCount, required this.percentage,
  });
  final String id;
  final String label;
  final int voteCount;
  final int percentage;

  factory HomeMatchdayPollOption.fromJson(Map<String, dynamic> json) =>
      HomeMatchdayPollOption(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toInt() ?? 0,
      );
}

class HomeMatchdayPoll {
  const HomeMatchdayPoll({
    required this.id, required this.question, required this.status,
    required this.totalVotes, required this.options, this.selectedOptionId,
  });
  final String id;
  final String question;
  final String status;
  final int totalVotes;
  final String? selectedOptionId;
  final List<HomeMatchdayPollOption> options;
  bool get isOpen => status == 'OPEN';

  factory HomeMatchdayPoll.fromJson(Map<String, dynamic> json) => HomeMatchdayPoll(
    id: json['id']?.toString() ?? '',
    question: json['question']?.toString() ?? '',
    status: json['status']?.toString() ?? 'CLOSED',
    totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
    selectedOptionId: json['selectedOptionId']?.toString(),
    options: ((json['options'] as List?) ?? const [])
        .whereType<Map>()
        .map((value) => HomeMatchdayPollOption.fromJson(Map<String, dynamic>.from(value)))
        .toList(),
  );
}

class HomeMatchdayPollService {
  HomeMatchdayPollService({Dio? dio}) : _dio = dio ?? DioClient.instance;
  final Dio _dio;

  Future<HomeMatchdayPoll?> get(int fixtureId, String competition) async {
    try {
      final response = await _dio.get('/football/matchday-polls/$fixtureId',
          queryParameters: {'competition': competition});
      final data = response.data['data'];
      return data is Map ? HomeMatchdayPoll.fromJson(Map<String, dynamic>.from(data)) : null;
    } on DioException catch (error) {
      // Older Railway deployments do not have this endpoint yet.
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<HomeMatchdayPoll> vote(int fixtureId, String competition, String optionId) async {
    final response = await _dio.put('/football/matchday-polls/$fixtureId/vote',
        queryParameters: {'competition': competition},
        data: {'optionId': optionId});
    return HomeMatchdayPoll.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
  }
}
