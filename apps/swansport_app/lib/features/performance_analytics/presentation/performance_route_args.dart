import 'package:swansport_models/swansport_models.dart';

class PerformanceDetailArgs {
  final SwanId athleteId;

  const PerformanceDetailArgs(this.athleteId);
}

class TeamPerformanceArgs {
  final SwanId teamId;
  const TeamPerformanceArgs(this.teamId);
}

class TestSessionArgs {
  final SwanId sessionId;
  const TestSessionArgs(this.sessionId);
}

class DevelopmentPlanArgs {
  final SwanId planId;
  const DevelopmentPlanArgs(this.planId);
}

class ReviewSessionArgs {
  final SwanId reviewId;
  const ReviewSessionArgs(this.reviewId);
}

class MatchPerformanceArgs {
  final SwanId recordId;
  const MatchPerformanceArgs(this.recordId);
}

class TrainingPerformanceArgs {
  final SwanId recordId;
  const TrainingPerformanceArgs(this.recordId);
}

class PositionAnalysisArgs {
  final SwanId positionId;
  const PositionAnalysisArgs(this.positionId);
}

class TestSessionEditorArgs {
  final SwanId? sessionId;
  const TestSessionEditorArgs({this.sessionId});
}

class DevelopmentPlanEditorArgs {
  final SwanId? planId;
  const DevelopmentPlanEditorArgs({this.planId});
}

class SelfAssessmentEditorArgs {
  final SwanId? assessmentId;
  const SelfAssessmentEditorArgs({this.assessmentId});
}

class ReviewSessionEditorArgs {
  final SwanId? reviewId;
  const ReviewSessionEditorArgs({this.reviewId});
}
