import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/project_timesheet_code.dart';

abstract class ProjectRepository {
  Future<Project?> getById(String id);
  Future<List<Project>> getAll(
      {String? workspaceId, bool includeArchived = false});
  Future<Project> create(Project project);
  Future<Project> update(Project project);
  Future<void> archive(String id);
  Future<void> unarchive(String id);
  Future<void> delete(String id);

  // Project Timesheet Codes
  Future<List<ProjectTimesheetCode>> getTimesheetCodes(String projectId);
  Future<List<ProjectTimesheetCode>> getAllTimesheetCodes({String? workspaceId});
  Future<void> setTimesheetCodes(
      String projectId, List<ProjectTimesheetCode> codes);
}
