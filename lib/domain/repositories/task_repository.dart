import 'package:workpulse/domain/models/task_model.dart';

abstract class TaskRepository {
  Future<List<Task>> getAllTasks();
  Future<Task?> getTaskById(String id);
  Future<List<Task>> getTasksByProject(String projectId);
  Future<List<Task>> getTasksByCategory(String categoryId);
  Future<List<Task>> searchTasks(String query);
  Future<List<Task>> getRecentTasks({int limit = 5});
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> updateLastWorkedAt(String taskId, DateTime lastWorkedAt);
  Future<void> deleteTask(String id);
}
