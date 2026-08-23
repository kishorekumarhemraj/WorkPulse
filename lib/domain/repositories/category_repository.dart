import 'package:workpulse/domain/models/category_model.dart';

abstract class CategoryRepository {
  Future<Category?> getById(String id);
  Future<List<Category>> getAll({String? workspaceId, bool includeArchived = false});
  Future<Category> create(Category category);
  Future<Category> update(Category category);
  Future<void> archive(String id);
  Future<void> unarchive(String id);
  Future<void> delete(String id);
}
