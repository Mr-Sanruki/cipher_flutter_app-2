import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

final userByIdProvider = FutureProvider.family<UserModel?, String>((ref, userId) async {
  final id = userId.trim();
  if (id.isEmpty) return null;
  final items = await ref.watch(authRepositoryProvider).getUsersByIds([id]);
  if (items.isEmpty) return null;
  return items.first;
});
