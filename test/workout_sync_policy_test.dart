import 'package:test/test.dart';
import 'package:ugk_exercise/product/workout_sync_policy.dart';

void main() {
  test('classifies stable Worker rejection reasons', () {
    for (final reason in [
      'invalid_workout',
      'invalid_client_session_id',
      'invalid_exercise_type',
      'invalid_metric',
      'session_limit_exceeded',
      'invalid_local_date',
      'invalid_timezone',
      'invalid_duration',
      'daily_limit_exceeded',
    ]) {
      expect(
        classifyWorkoutSyncRejection(reason),
        WorkoutSyncRejectionDisposition.terminal,
        reason: reason,
      );
    }

    expect(
      classifyWorkoutSyncRejection('premium_required'),
      WorkoutSyncRejectionDisposition.blockedOnPremium,
    );
    expect(
      classifyWorkoutSyncRejection('future_ended_at'),
      WorkoutSyncRejectionDisposition.retryable,
    );
    expect(
      classifyWorkoutSyncRejection('new_server_reason'),
      WorkoutSyncRejectionDisposition.protocolError,
    );
  });
}
