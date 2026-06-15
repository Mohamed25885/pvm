enum SetupFailureReason {
  pvmHomeNotReadable,
  versionsHomeNotWritable,
  cannotWriteEnvironment,
  pathUpdateFailed,
}

class SetupCheckResult {
  final bool success;
  final String? message;
  final SetupFailureReason? reason;

  const SetupCheckResult._({required this.success, this.message, this.reason});

  const SetupCheckResult.ok() : this._(success: true);

  const SetupCheckResult.fail(SetupFailureReason reason, String message)
    : this._(success: false, reason: reason, message: message);
}
