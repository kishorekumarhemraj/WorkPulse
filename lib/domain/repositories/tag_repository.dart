import 'package:workpulse/domain/models/tag_model.dart';

abstract class TagRepository {
  Future<Tag?> getById(String id);
  Future<List<Tag>> getAll({String? workspaceId});
  Future<Tag> create(Tag tag);
  Future<Tag> update(Tag tag);
  Future<void> delete(String id);
}
