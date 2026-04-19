import '../../lib/src/core/process_manager.dart';

/// Test double for [IProcessManager] that records captured specs and returns
/// configurable exit codes.
class FakeProcessManager implements IProcessManager {
  final List<ProcessSpec> capturedSpecs = [];
  ProcessSpec? lastSpec;
  int mockExitCode = 0;
  bool shouldThrow = false;

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    capturedSpecs.add(spec);
    lastSpec = spec;
    if (shouldThrow) {
      throw Exception('Mock process failed');
    }
    return mockExitCode;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    throw UnimplementedError('runCaptured not needed for these tests');
  }

  void reset() {
    capturedSpecs.clear();
    lastSpec = null;
    mockExitCode = 0;
    shouldThrow = false;
  }
}
