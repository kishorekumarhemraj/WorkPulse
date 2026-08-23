import 'package:workpulse/domain/models/tag_model.dart';

abstract class TagRepository {
  Future<List<Tag>> getAllTags();
  Future<Tag?> getTagById(String id);
  Future<Tag?> getTagByName(String name);
  Future<List<Tag>> getTagsForTask(String taskId);
  Future<void> createTag(Tag tag);
  Future<void> updateTag(Tag tag);
  Future<void> deleteTag(String id);
}
