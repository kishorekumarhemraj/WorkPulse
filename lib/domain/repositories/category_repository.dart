import 'package:workpulse/domain/models/category_model.dart';

abstract class CategoryRepository {
  Future<List<Category>> getAllCategories({bool includeArchived = false});
  Future<Category?> getCategoryById(String id);
  Future<Category?> getCategoryByName(String name);
  Future<void> createCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> deleteCategory(String id);
}
