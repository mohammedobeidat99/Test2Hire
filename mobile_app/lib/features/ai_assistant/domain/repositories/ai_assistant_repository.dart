import 'package:mobile_app/features/ai_assistant/domain/entities/candidate_ai_summary.dart';
import 'package:mobile_app/features/ai_assistant/domain/entities/candidate_comparison_result.dart';

abstract class AiAssistantRepository {
  Stream<CandidateAiSummary?> listenAiSummary(String applicationId);
  Future<CandidateAiSummary?> getAiSummary(String applicationId);
  Future<CandidateAiSummary> generateCandidateAiSummary(String applicationId);
  Future<CandidateComparisonResult> compareCandidates({
    required List<String> applicationIds,
    required String jobId,
  });
}
