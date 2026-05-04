import 'diagnostic_models.dart';

/// One self-contained diagnostic step run by [DoctorCommand].
abstract class DiagnosticCheck {
  String get id;
  String get label;

  Future<DiagnosticResult> run();
}
