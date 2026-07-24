enum WorkoutSyncRejectionDisposition {
  terminal,
  blockedOnPremium,
  retryable,
  protocolError,
}

WorkoutSyncRejectionDisposition classifyWorkoutSyncRejection(String reason) {
  switch (reason) {
    case 'premium_required':
      return WorkoutSyncRejectionDisposition.blockedOnPremium;
    case 'future_ended_at':
      return WorkoutSyncRejectionDisposition.retryable;
    case 'invalid_workout':
    case 'invalid_client_session_id':
    case 'invalid_exercise_type':
    case 'invalid_metric':
    case 'session_limit_exceeded':
    case 'invalid_local_date':
    case 'invalid_timezone':
    case 'invalid_duration':
    case 'daily_limit_exceeded':
      return WorkoutSyncRejectionDisposition.terminal;
    default:
      return WorkoutSyncRejectionDisposition.protocolError;
  }
}
